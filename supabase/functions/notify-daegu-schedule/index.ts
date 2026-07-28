import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

/** 앱 권한과 동일: 대구지사장·관리자 그룹 (+ role=admin) */
const ALLOWED_GROUP_NAMES = ['대구지사장', '관리자']

type PushUser = { id: string; name: string; role: string; fcm_token: string }

type SchedulePayload = {
  action?: string
  scheduleData?: Record<string, unknown>
}

function actionTitle(
  action: string,
  scheduleData: Record<string, unknown>,
): string {
  const site = (scheduleData.site ?? '').toString().trim()
  let label: string
  switch (action) {
    case 'created':
      label = '일정 등록'
      break
    case 'updated':
      label = '일정 수정'
      break
    case 'deleted':
      label = '일정 삭제'
      break
    default:
      label = '일정'
  }
  return site ? `[대구지사] ${label} · ${site}` : `[대구지사] ${label}`
}

function buildBody(scheduleData: Record<string, unknown>): string {
  const alarmText = (scheduleData.alarm_text ?? '').toString().trim()
  if (alarmText) return alarmText

  const site = (scheduleData.site ?? '').toString().trim()
  const user = (scheduleData.user_name ?? scheduleData.entered_by ?? '')
    .toString()
    .trim()
  const start = (scheduleData.start_date ?? '').toString().trim()
  const parts = [
    site ? `현장: ${site}` : '',
    user && start ? `입력: ${user} · ${start}` : user ? `입력: ${user}` : '',
  ].filter(Boolean)
  return parts.join('\n') || '대구지사 일정이 변경되었습니다.'
}

/** FCM data 필드용 — 줄바꿈 유지. */
function buildDataBody(body: string): string {
  return body.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim()
}

async function resolveDaeguSchedulePushRecipients(
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<PushUser[]> {
  const { data, error } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, is_active, groups(name)')
    .eq('is_active', true)
    .not('fcm_token', 'is', null)

  if (error) throw error

  const byId = new Map<string, PushUser>()
  for (const raw of data ?? []) {
    const row = raw as Record<string, unknown>
    const groups = row.groups as { name?: string } | null
    const groupName = (groups?.name ?? '').toString().trim()
    const role = (row.role ?? '').toString().trim()
    const allowed =
      role === 'admin' || ALLOWED_GROUP_NAMES.includes(groupName)
    if (!allowed) continue

    const id = (row.id ?? '').toString()
    const token = (row.fcm_token ?? '').toString().trim()
    if (!id || !token) continue

    byId.set(id, {
      id,
      name: (row.name ?? '').toString(),
      role,
      fcm_token: token,
    })
  }
  return Array.from(byId.values())
}

serve(async (req) => {
  try {
    const payload = (await req.json()) as SchedulePayload
    const action = (payload.action ?? 'created').toString()
    const scheduleData = (payload.scheduleData ?? {}) as Record<string, unknown>

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const users = await resolveDaeguSchedulePushRecipients(supabaseAdmin)
    const tokens = Array.from(
      new Set(
        users
          .map((u) => (u.fcm_token ?? '').trim())
          .filter((t) => t.length > 5),
      ),
    )

    if (tokens.length === 0) {
      console.log('No daegu schedule FCM recipients in 대구지사장/관리자')
      return new Response(
        JSON.stringify({
          success: true,
          recipientCount: 0,
          message: 'No FCM recipients in 대구지사장/관리자',
        }),
        { headers: { 'Content-Type': 'application/json' }, status: 200 },
      )
    }

    console.log(
      `Routing daegu schedule ${action} push to ${tokens.length} token(s):`,
      users.map((u) => `${u.name}(Token OK)`).join(', '),
    )

    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(
      Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}',
    )

    const auth = new GoogleAuth({
      credentials: FIREBASE_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const client = await auth.getClient()
    const accessTokenResponse = await client.getAccessToken()
    const accessToken = accessTokenResponse.token

    if (!accessToken) {
      throw new Error('Failed to get FCM access token')
    }

    const title = actionTitle(action, scheduleData)
    const body = buildBody(scheduleData)
    const dataBody = buildDataBody(body)

    console.log(`Sending daegu schedule ${action} push: title=${title}`)

    const results = await Promise.all(
      tokens.map(async (token: string) => {
        try {
          const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: {
                  token,
                  data: {
                    type: 'daegu_schedule',
                    action: 'open_daegu_schedule',
                    title,
                    body: dataBody,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  android: { priority: 'high' },
                },
              }),
            },
          )
          const resText = await res.text()
          console.log(`FCM Response (Status: ${res.status}):`, resText)
          if (res.status === 404 && resText.includes('UNREGISTERED')) {
            await supabaseAdmin
              .from('users')
              .update({ fcm_token: null })
              .eq('fcm_token', token)
          }
          return { status: res.status, body: resText }
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e)
          console.error('FCM error:', msg)
          return { error: msg }
        }
      }),
    )

    return new Response(
      JSON.stringify({
        success: true,
        recipientCount: tokens.length,
        recipients: users.map((u) => u.name),
        results,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error('notify-daegu-schedule error:', msg)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
