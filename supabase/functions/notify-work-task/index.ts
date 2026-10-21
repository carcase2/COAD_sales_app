import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

const LAB_GROUPS = new Set(['연구소', '관리자'])
const OPEN_NAMES = new Set(['접수', '진행중'])

type PushUser = { id: string; name: string; fcm_token?: string | null }

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

function ymd(raw: unknown): string {
  const text = (raw ?? '').toString().trim()
  return text.length >= 10 ? text.slice(0, 10) : ''
}

function groupName(groups: unknown): string {
  if (!groups) return ''
  if (Array.isArray(groups)) {
    const first = groups[0] as { name?: string } | undefined
    return (first?.name ?? '').toString().trim()
  }
  return ((groups as { name?: string }).name ?? '').toString().trim()
}

async function claimDedupe(admin: SupabaseClient, key: string): Promise<boolean> {
  const { error } = await admin.from('work_push_dedup').insert({ dedupe_key: key })
  if (!error) return true
  const code = (error as { code?: string }).code ?? ''
  if (code === '23505') return false
  console.error('work_push_dedup insert failed, sending anyway:', error)
  return true
}

async function recipients(admin: SupabaseClient): Promise<PushUser[]> {
  const { data, error } = await admin
    .from('users')
    .select('id, name, fcm_token, is_active, groups(name)')
    .eq('is_active', true)
  if (error) throw error
  const users: PushUser[] = []
  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    if (!LAB_GROUPS.has(groupName(row.groups))) continue
    const id = (row.id ?? '').toString()
    if (!id) continue
    users.push({
      id,
      name: (row.name ?? '').toString(),
      fcm_token: (row.fcm_token ?? null) as string | null,
    })
  }
  return users
}

async function tokens(admin: SupabaseClient, users: PushUser[]): Promise<string[]> {
  const ids = users.map((user) => user.id).filter((id) => id.length > 0)
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
  const legacy = users
    .map((user) => (user.fcm_token ?? '').toString().trim())
    .filter((token) => token.length > 5)
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

async function sendPush(
  admin: SupabaseClient,
  pushTokens: string[],
  message: { title: string; body: string; kind: string; notificationId: string; taskId?: string },
): Promise<number> {
  if (pushTokens.length === 0) return 0
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')
  const account = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')
  const auth = new GoogleAuth({
    credentials: account,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const client = await auth.getClient()
  const access = await client.getAccessToken()
  const accessToken = access.token
  if (!accessToken) throw new Error('FCM access token 없음')

  const data: Record<string, string> = {
    type: 'work_tasks',
    action: 'open_work_tasks',
    kind: message.kind,
    title: message.title,
    body: message.body,
    notification_id: message.notificationId,
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  }
  if (message.taskId) data.task_id = message.taskId

  await Promise.all(
    pushTokens.map(async (token) => {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                data,
                android: { priority: 'high' },
                apns: {
                  headers: { 'apns-push-type': 'alert', 'apns-priority': '10' },
                  payload: {
                    aps: {
                      alert: { title: message.title, body: message.body },
                      sound: 'default',
                    },
                  },
                },
              },
            }),
          },
        )
        const text = await res.text()
        if (res.status === 404 && text.includes('UNREGISTERED')) {
          await deactivate(admin, token)
        } else if (!res.ok) {
          console.error('FCM', res.status, text)
        }
      } catch (error) {
        console.error('FCM send failed:', error)
      }
    }),
  )
  return pushTokens.length
}

function noteId(seed: string): string {
  let hash = 0
  for (let i = 0; i < seed.length; i++) {
    hash = (Math.imul(hash, 33) + seed.charCodeAt(i)) >>> 0
  }
  return String(93000 + (hash % 6000))
}

function lineOf(title: string, due: string, today: string): string {
  const name = title.trim() || '제목 없음'
  if (!due) return name
  if (due < today) return `${name} · 기한 지남`
  if (due === today) return `${name} · 오늘 마감`
  return `${name} · ${due.slice(5)}`
}

async function nameMap(admin: SupabaseClient): Promise<Map<string, string>> {
  const { data } = await admin.from('user_roles').select('user_email, display_name').limit(200)
  const map = new Map<string, string>()
  for (const row of (data ?? []) as Array<{ user_email?: string; display_name?: string }>) {
    const email = (row.user_email ?? '').trim()
    if (!email) continue
    map.set(email, (row.display_name ?? '').trim() || email.split('@')[0])
  }
  return map
}

serve(async (req) => {
  try {
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const users = await recipients(admin)
    const pushTokens = await tokens(admin, users)
    const mode = (body.mode ?? '').toString()

    if (mode === 'morning') {
      const today = todayKst()
      const { data: statuses } = await admin.from('task_statuses').select('id, name')
      const openIds = ((statuses ?? []) as Array<{ id: string; name: string }>)
        .filter((row) => OPEN_NAMES.has(row.name))
        .map((row) => row.id)
      const { data: deptRows } = await admin
        .from('departments')
        .select('id')
        .eq('name', '연구소')
        .limit(1)
      const deptId = (deptRows?.[0] as { id?: string } | undefined)?.id
      if (!deptId || openIds.length === 0) {
        return json({ success: true, sent: 0, reason: 'no-open-status' })
      }
      const { data: tasks, error } = await admin
        .from('tasks')
        .select('title, due_date')
        .eq('department_id', deptId)
        .in('status_id', openIds)
        .order('due_date', { ascending: true, nullsFirst: false })
        .limit(300)
      if (error) throw error
      const rows = (tasks ?? []) as Array<{ title?: string; due_date?: string | null }>
      const remaining = rows.length
      const dueToday = rows.filter((row) => ymd(row.due_date) === today)
      if (remaining === 0) return json({ success: true, sent: 0, remaining: 0 })
      const claimed = await claimDedupe(admin, `morning:${today}`)
      if (!claimed) return json({ success: true, skipped: 'already-sent', today })

      const preview = (list: Array<{ title?: string; due_date?: string | null }>) =>
        list
          .slice(0, 5)
          .map((row) => lineOf((row.title ?? '').toString(), ymd(row.due_date), today))
          .join('\n')

      const overdue = rows.filter((row) => {
        const due = ymd(row.due_date)
        return due !== '' && due < today
      }).length
      const remainingBody = [
        overdue > 0 ? `기한 지남 ${overdue}건` : '',
        dueToday.length > 0 ? `오늘 마감 ${dueToday.length}건` : '',
        preview(rows),
      ]
        .filter(Boolean)
        .join('\n')

      let sent = await sendPush(admin, pushTokens, {
        title: `남은 업무 ${remaining}건`,
        body: remainingBody || '알림을 누르면 남은 업무를 볼 수 있습니다.',
        kind: 'morning_remaining',
        notificationId: '92008',
      })
      if (dueToday.length > 0) {
        sent += await sendPush(admin, pushTokens, {
          title: `오늘 마감 ${dueToday.length}건`,
          body: preview(dueToday) || '오늘 마감 업무가 있습니다.',
          kind: 'morning_due',
          notificationId: '92009',
        })
      }
      return json({ success: true, sent, recipients: users.map((user) => user.name) })
    }

    const kind = (body.kind ?? '').toString()
    const record = (body.record ?? {}) as Record<string, unknown>
    const taskId = (record.id ?? '').toString()
    const titleText = (record.title ?? '').toString().trim() || '제목 없음'
    if (!taskId || (kind !== 'added' && kind !== 'status')) {
      return json({ success: true, skipped: 'ignored' })
    }

    const { data: statuses } = await admin.from('task_statuses').select('id, name')
    const statusName = new Map(
      ((statuses ?? []) as Array<{ id: string; name: string }>).map((row) => [row.id, row.name]),
    )
    const nextStatus = statusName.get((record.status_id ?? '').toString()) ?? ''
    const stamp = (record.updated_at ?? record.created_at ?? taskId).toString()
    const dedupeKey = kind === 'added' ? `added:${taskId}` : `status:${taskId}:${record.status_id}:${stamp}`
    if (!(await claimDedupe(admin, dedupeKey))) {
      return json({ success: true, skipped: 'duplicate' })
    }

    const names = await nameMap(admin)
    const assigneeLabel = (Array.isArray(record.assignees) ? record.assignees : [])
      .map((email) => names.get((email ?? '').toString()) ?? '')
      .filter(Boolean)
      .join(', ')
    const due = ymd(record.due_date)
    const detailBits = [
      assigneeLabel ? `담당 ${assigneeLabel}` : '',
      due ? `마감 ${due}` : '',
    ].filter(Boolean)

    let headline = '업무 상태가 바뀌었습니다'
    if (kind === 'added') headline = '업무가 추가되었습니다'
    else if (nextStatus === '완료') headline = '업무가 완료되었습니다'
    else if (nextStatus === '진행중') headline = '업무가 시작되었습니다'
    else if (nextStatus === '보류') headline = '업무가 보류되었습니다'
    else if (nextStatus === '접수') headline = '업무가 접수로 바뀌었습니다'

    const sent = await sendPush(admin, pushTokens, {
      title: headline,
      body: [titleText, ...detailBits].join('\n'),
      kind,
      notificationId: noteId(`${kind}:${taskId}:${nextStatus}`),
      taskId,
    })
    return json({ success: true, sent, title: headline })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('notify-work-task error:', message)
    return json({ error: message }, 500)
  }
})
