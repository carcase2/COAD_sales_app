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

function todayKstYmd(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function kstHour(): number {
  const raw = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    hour: 'numeric',
    hour12: false,
  }).format(new Date())
  const n = Number(raw)
  return Number.isFinite(n) ? n : 0
}

function slotNotificationId(): number {
  const hour = kstHour()
  if (hour < 12) return 91009
  if (hour < 16) return 91013
  return 91018
}

function ymdOf(raw: unknown): string {
  const s = (raw ?? '').toString().trim()
  return s.length >= 10 ? s.slice(0, 10) : s
}

function parseSendYmd(description: string): string | null {
  const lines = description.split('\n')
  for (const line of lines) {
    const m = line
      .trim()
      .match(/^\[결과:\s*견적서 발송(?:\s*·\s*발송예정\s*(\d{4}-\d{2}-\d{2}))?\]$/)
    if (m?.[1]) return m[1]
  }
  return null
}

function isCompleted(status: unknown): boolean {
  return Number(status) === 1
}

function isCsRecipient(u: PushUser): boolean {
  const role = (u.role ?? '').toString().trim().toLowerCase()
  const groupName = (u.groups?.name ?? '').toString().trim()
  return role === 'admin' || CS_GROUPS.has(groupName)
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

async function loadDueCounts(): Promise<{
  todayVisit: number
  overdueVisit: number
  todaySend: number
  overdueSend: number
}> {
  const url =
    Deno.env.get('SUPPORT_SUPABASE_URL') ??
    Deno.env.get('NEXT_PUBLIC_SUPPORT_SUPABASE_URL') ??
    ''
  const key =
    Deno.env.get('SUPPORT_SUPABASE_ANON_KEY') ??
    Deno.env.get('NEXT_PUBLIC_SUPPORT_SUPABASE_ANON_KEY') ??
    ''
  if (!url || !key) {
    throw new Error('SUPPORT_SUPABASE_URL / SUPPORT_SUPABASE_ANON_KEY missing')
  }
  const support = createClient(url, key)
  const today = todayKstYmd()
  const counts = {
    todayVisit: 0,
    overdueVisit: 0,
    todaySend: 0,
    overdueSend: 0,
  }

  const { data: visits, error: visitError } = await support
    .from('call_logs')
    .select('id, visit_date, service_status_id')
    .not('visit_date', 'is', null)
    .lte('visit_date', today)
    .limit(500)
  if (visitError) throw visitError
  for (const row of visits ?? []) {
    if (isCompleted(row.service_status_id)) continue
    const ymd = ymdOf(row.visit_date)
    if (!ymd) continue
    if (ymd === today) counts.todayVisit += 1
    else if (ymd < today) counts.overdueVisit += 1
  }

  const { data: reqs, error: reqError } = await support
    .from('service_requests')
    .select('description, call_log_id')
    .ilike('description', '%발송예정%')
    .limit(500)
  if (reqError) {
    console.error('send-date query failed:', reqError)
    return counts
  }
  const ymdByLogId = new Map<string, string>()
  for (const row of reqs ?? []) {
    const ymd = parseSendYmd((row.description ?? '').toString())
    const id = (row.call_log_id ?? '').toString()
    if (!ymd || !id || ymd > today) continue
    ymdByLogId.set(id, ymd)
  }
  if (ymdByLogId.size === 0) return counts

  const { data: logs, error: logError } = await support
    .from('call_logs')
    .select('id, service_status_id')
    .in('id', Array.from(ymdByLogId.keys()))
    .limit(400)
  if (logError) {
    console.error('send-date logs failed:', logError)
    return counts
  }
  for (const row of logs ?? []) {
    if (isCompleted(row.service_status_id)) continue
    const ymd = ymdByLogId.get((row.id ?? '').toString())
    if (!ymd) continue
    if (ymd === today) counts.todaySend += 1
    else if (ymd < today) counts.overdueSend += 1
  }
  return counts
}

function buildBody(counts: {
  todayVisit: number
  overdueVisit: number
  todaySend: number
  overdueSend: number
}): string {
  const parts: string[] = []
  if (counts.todayVisit > 0) parts.push(`오늘 방문 ${counts.todayVisit}건`)
  if (counts.todaySend > 0) parts.push(`오늘 발송 ${counts.todaySend}건`)
  if (counts.overdueVisit > 0) parts.push(`지난 방문 ${counts.overdueVisit}건`)
  if (counts.overdueSend > 0) parts.push(`지난 발송 ${counts.overdueSend}건`)
  return parts.join(' · ')
}

serve(async (_req) => {
  try {
    const counts = await loadDueCounts()
    const body = buildBody(counts)
    if (!body) {
      return new Response(
        JSON.stringify({ message: 'No due or overdue A/S schedules', counts }),
        { headers: { 'Content-Type': 'application/json' }, status: 200 },
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const users = await resolveCsUsers(supabaseAdmin)
    if (users.length === 0) {
      return new Response(JSON.stringify({ message: 'No CS/admin users found' }), {
        status: 200,
      })
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

    const title = '[A/S] 방문·발송 예정'
    const notifId = String(slotNotificationId())
    console.log(
      `A/S due push body=${body} users=${users.map((u) => u.name).join(',')} tokens=${tokens.length}`,
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
                  data: {
                    type: 'as_due_schedule',
                    action: 'open_as_calendar',
                    title,
                    body,
                    notification_id: notifId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                  android: { priority: 'high' },
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
        counts,
        body,
        recipientCount: tokens.length,
        recipientUsers: users.map((u) => u.name),
        results,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error)
    console.error('notify-as-due-schedule error:', msg)
    return new Response(JSON.stringify({ error: msg }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
