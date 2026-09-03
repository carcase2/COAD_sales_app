import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

type PushUser = {
  id: string
  name: string
  role: string
  groups?: { name?: string | null } | null
  fcm_token?: string | null
}

const CS_GROUPS = new Set(['고객지원', '고객지원팀', '관리자'])

/** 임시: 고객지원 알림을 받을 추가 계정(아이디 또는 이름). */
const EXTRA_CS_NOTIFY = new Set(['남현우'])

function isCsRecipient(u: PushUser): boolean {
  const role = (u.role ?? '').toString().trim().toLowerCase()
  const groupName = (u.groups?.name ?? '').toString().trim()
  const id = (u.id ?? '').toString().trim()
  const name = (u.name ?? '').toString().trim()
  return (
    role === 'admin' ||
    CS_GROUPS.has(groupName) ||
    EXTRA_CS_NOTIFY.has(id) ||
    EXTRA_CS_NOTIFY.has(name)
  )
}

async function resolveCsUsers(
  supabaseAdmin: ReturnType<typeof createClient>,
): Promise<PushUser[]> {
  const { data: users, error } = await supabaseAdmin
    .from('users')
    .select('id, name, role, fcm_token, groups(name)')

  if (error) throw error
  return (users ?? []).filter((u) => u?.id && isCsRecipient(u))
}

async function resolvePushTokens(
  supabaseAdmin: ReturnType<typeof createClient>,
  users: PushUser[],
): Promise<string[]> {
  const userIds = Array.from(
    new Set(users.map((u) => (u.id ?? '').toString()).filter((id) => id.length > 0)),
  )
  if (userIds.length === 0) return []

  const { data: tokenRows, error: tokenError } = await supabaseAdmin
    .from('user_push_tokens')
    .select('fcm_token')
    .in('user_id', userIds)
    .eq('is_active', true)
    .not('fcm_token', 'is', null)

  if (tokenError) {
    console.error('Error loading user_push_tokens:', tokenError)
  }

  const tableTokens = (tokenRows ?? [])
    .map((r) => (r?.fcm_token ?? '').toString().trim())
    .filter((t) => t.length > 5)
  const legacyTokens = users
    .map((u) => (u.fcm_token ?? '').toString().trim())
    .filter((t) => t.length > 5)
  return Array.from(new Set([...tableTokens, ...legacyTokens]))
}

async function deactivateInvalidToken(
  supabaseAdmin: ReturnType<typeof createClient>,
  token: string,
): Promise<void> {
  try {
    await supabaseAdmin
      .from('user_push_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('fcm_token', token)
    await supabaseAdmin.from('users').update({ fcm_token: null }).eq('fcm_token', token)
  } catch (e) {
    console.error('Failed to deactivate invalid token:', e)
  }
}

serve(async (req) => {
  try {
    const payload = await req.json()
    const record = (payload?.record ?? payload ?? {}) as Record<string, unknown>
    const asId = (record.id ?? record.as_id ?? '').toString().trim()
    if (!asId) {
      return new Response(JSON.stringify({ error: 'Missing A/S id' }), { status: 400 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const users = await resolveCsUsers(supabaseAdmin)
    if (users.length === 0) {
      return new Response(JSON.stringify({ message: 'No CS/admin users found' }), { status: 200 })
    }

    const tokens = await resolvePushTokens(supabaseAdmin, users)
    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({
          message: 'No FCM tokens for CS/admin',
          recipientUsers: users.map((u) => u.name),
        }),
        { status: 200 },
      )
    }

    const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID')
    const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
    const auth = new GoogleAuth({
      credentials: FIREBASE_SERVICE_ACCOUNT,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })
    const client = await auth.getClient()
    const accessToken = (await client.getAccessToken()).token
    if (!accessToken) throw new Error('Failed to get FCM access token')

    const customerName = (record.customer_name ?? '이름없음').toString()
    const phone = (record.customer_phone ?? '').toString()
    const createdBy = (record.created_by ?? '').toString().trim()
    const issue = (record.issue ?? '').toString().replace(/\s+/g, ' ').trim()
    const title = `[A/S] ${customerName}`
    const body = [
      phone ? `📞 ${phone}` : '',
      createdBy ? `작성 ${createdBy}` : '',
      issue ? `📝 ${issue}` : '새 A/S 접수가 등록되었습니다.',
    ]
      .filter((s) => s.length > 0)
      .join(' · ')

    console.log(
      `A/S push asId=${asId} users=${users.map((u) => u.name).join(',')} tokens=${tokens.length}`,
    )

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
                  // iOS는 data-only면 백그라운드/종료 시 배너가 안 뜸. notification + apns alert 필수.
                  notification: { title, body },
                  data: {
                    type: 'as_reception',
                    as_id: asId,
                    title,
                    body,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  android: {
                    priority: 'high',
                    notification: {
                      channel_id: 'call_notifications',
                      sound: 'default',
                    },
                  },
                  apns: {
                    headers: {
                      'apns-push-type': 'alert',
                      'apns-priority': '10',
                    },
                    payload: {
                      aps: {
                        alert: { title, body },
                        sound: 'default',
                      },
                    },
                  },
                },
              }),
            },
          )
          const resText = await res.text()
          console.log(`FCM Response (Status: ${res.status}):`, resText)
          if (res.status === 404 && resText.includes('UNREGISTERED')) {
            await deactivateInvalidToken(supabaseAdmin, token)
          }
          return { status: res.status, body: resText }
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e)
          return { error: msg }
        }
      }),
    )

    return new Response(
      JSON.stringify({
        success: true,
        recipientCount: tokens.length,
        recipientUsers: users.map((u) => u.name),
        results,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error('Error:', msg)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
