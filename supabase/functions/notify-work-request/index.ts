import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'
import { requestPush, type RequestRecord } from './message.ts'

// work_requests 트리거(trg_notify_work_request)가 부른다. 앱·웹 어디서 바꿔도 같이 알린다.

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function todayKst(): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function groupName(groups: unknown): string {
  if (!groups) return ''
  if (Array.isArray(groups)) return ((groups[0] as { name?: string } | undefined)?.name ?? '').toString().trim()
  return ((groups as { name?: string }).name ?? '').toString().trim()
}

type PushUser = { id: string; fcm_token: string | null }

async function claimDedupe(admin: SupabaseClient, key: string): Promise<boolean> {
  const { error } = await admin.from('work_push_dedup').insert({ dedupe_key: key })
  if (!error) return true
  if ((error as { code?: string }).code === '23505') return false
  console.error('work_push_dedup insert failed, sending anyway:', error)
  return true
}

async function groupUsers(admin: SupabaseClient, group: string, excludeUserId: string): Promise<PushUser[]> {
  const { data, error } = await admin
    .from('users')
    .select('id, fcm_token, is_active, groups(name)')
    .eq('is_active', true)
  if (error) throw error
  const users: PushUser[] = []
  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    const id = (row.id ?? '').toString()
    if (!id || id === excludeUserId) continue
    if (groupName(row.groups) !== group) continue
    users.push({ id, fcm_token: (row.fcm_token ?? null) as string | null })
  }
  return users
}

async function oneUser(admin: SupabaseClient, userId: string): Promise<PushUser[]> {
  const { data, error } = await admin
    .from('users')
    .select('id, fcm_token, is_active')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  const row = data as { id?: string; fcm_token?: string | null; is_active?: boolean | null } | null
  if (!row?.id || row.is_active === false) return []
  return [{ id: String(row.id), fcm_token: row.fcm_token ?? null }]
}

async function tokens(admin: SupabaseClient, users: PushUser[]): Promise<string[]> {
  const ids = users.map((user) => user.id)
  if (ids.length === 0) return []
  const { data, error } = await admin
    .from('user_push_tokens')
    .select('fcm_token')
    .in('user_id', ids)
    .eq('is_active', true)
    .not('fcm_token', 'is', null)
  if (error) console.error('user_push_tokens:', error)
  const fromTable = (data ?? [])
    .map((row) => (row?.fcm_token ?? '').toString().trim())
    .filter((token) => token.length > 5)
  const legacy = users.map((user) => (user.fcm_token ?? '').trim()).filter((token) => token.length > 5)
  return Array.from(new Set([...fromTable, ...legacy]))
}

async function deactivate(admin: SupabaseClient, token: string): Promise<void> {
  try {
    await admin
      .from('user_push_tokens')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('fcm_token', token)
    await admin.from('users').update({ fcm_token: null }).eq('fcm_token', token)
  } catch (error) {
    console.error('deactivate token failed:', error)
  }
}

function noteId(seed: string): string {
  let hash = 0
  for (let i = 0; i < seed.length; i++) hash = (Math.imul(hash, 33) + seed.charCodeAt(i)) >>> 0
  return String(99000 + (hash % 900))
}

async function sendPush(
  admin: SupabaseClient,
  pushTokens: string[],
  message: { title: string; body: string; requestId: string; kind: string },
): Promise<number> {
  if (pushTokens.length === 0) return 0
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
  const account = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
  const auth = new GoogleAuth({
    credentials: account,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const access = await (await auth.getClient()).getAccessToken()
  if (!access.token) throw new Error('FCM access token 없음')

  const data: Record<string, string> = {
    type: 'work_requests',
    action: 'open_work_requests',
    kind: message.kind,
    title: message.title,
    body: message.body,
    request_id: message.requestId,
    // 같은 요청 알림은 한 칸에서 갈아끼운다.
    notification_id: noteId(`request:${message.requestId}`),
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  }

  await Promise.all(
    pushTokens.map(async (token) => {
      try {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${access.token}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: {
              token,
              data,
              android: { priority: 'high' },
              apns: {
                headers: {
                  'apns-push-type': 'alert',
                  'apns-priority': '10',
                  'apns-collapse-id': `request-${message.requestId}`,
                },
                payload: { aps: { alert: { title: message.title, body: message.body }, sound: 'default' } },
              },
            },
          }),
        })
        const text = await res.text()
        if (res.status === 404 && text.includes('UNREGISTERED')) await deactivate(admin, token)
        else if (!res.ok) console.error('FCM', res.status, text)
      } catch (error) {
        console.error('FCM send failed:', error)
      }
    }),
  )
  return pushTokens.length
}

serve(async (req) => {
  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>
    const op = (body.type ?? '').toString() === 'INSERT' ? 'INSERT' : 'UPDATE'
    const record = (body.record ?? {}) as RequestRecord
    const old = (body.old_record ?? {}) as RequestRecord
    const push = requestPush(op, record, old, todayKst())
    if (!push) return json({ success: true, skipped: 'nothing-to-tell' })

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    if (!(await claimDedupe(admin, push.key))) return json({ success: true, skipped: 'duplicate' })

    const users = push.audience === 'group'
      ? await groupUsers(admin, push.group, push.excludeUserId)
      : await oneUser(admin, push.userId)
    const sent = await sendPush(admin, await tokens(admin, users), {
      title: push.title,
      body: push.body,
      requestId: (record.id ?? '').toString(),
      kind: push.audience === 'group' ? 'request_added' : 'request_changed',
    })
    return json({ success: true, sent, title: push.title })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('notify-work-request error:', message)
    return json({ error: message }, 500)
  }
})
