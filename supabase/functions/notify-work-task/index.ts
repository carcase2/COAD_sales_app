import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'
import { workCommentMessage, workTaskMessage } from './message.ts'

const LAB_GROUPS = new Set(['연구소', '관리자'])
const OPEN_NAMES = new Set(['접수', '진행중'])
/** 연달아 바뀐 상태를 한 알림으로 모으려고 기다리는 시간. */
const SETTLE_MS = 20_000

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
  message: {
    title: string
    body: string
    kind: string
    notificationId: string
    taskId?: string
    collapseId?: string
  },
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
                  headers: {
                    'apns-push-type': 'alert',
                    'apns-priority': '10',
                    ...(message.collapseId ? { 'apns-collapse-id': message.collapseId } : {}),
                  },
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

/** work-tasks restore 가 남긴 `silent:<업무 id>:` 행이 2분 안에 있으면 지우고 true. */
async function consumeSilent(admin: SupabaseClient, taskId: string): Promise<boolean> {
  const since = new Date(Date.now() - 2 * 60_000).toISOString()
  const { data, error } = await admin
    .from('work_push_dedup')
    .select('dedupe_key')
    .like('dedupe_key', `silent:${taskId}:%`)
    .gte('sent_at', since)
    .limit(1)
  if (error || !data || data.length === 0) return false
  await admin.from('work_push_dedup').delete().eq('dedupe_key', data[0].dedupe_key)
  return true
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

    if (kind === 'comment') {
      // task_comments 트리거 — 연구소 업무 댓글만, 쓴 사람은 빼고 알린다.
      const commentId = (record.id ?? '').toString()
      const commentTaskId = (record.task_id ?? '').toString()
      if (!commentId || !commentTaskId) return json({ success: true, skipped: 'ignored' })
      if (!(await claimDedupe(admin, `comment:${commentId}`))) {
        return json({ success: true, skipped: 'duplicate' })
      }
      const { data: deptRows } = await admin.from('departments').select('id').eq('name', '연구소').limit(1)
      const labDept = (deptRows?.[0] as { id?: string } | undefined)?.id
      const { data: taskRow } = await admin
        .from('tasks')
        .select('id, title, department_id')
        .eq('id', commentTaskId)
        .maybeSingle()
      const commented = taskRow as { title?: string; department_id?: string } | null
      if (!commented || !labDept || commented.department_id !== labDept) {
        return json({ success: true, skipped: 'not-lab-task' })
      }
      const authorEmail = (record.author_email ?? '').toString().trim()
      const names = await nameMap(admin)
      const author = names.get(authorEmail) ?? authorEmail.split('@')[0]
      const others = users.filter((user) => user.name.trim() !== author.trim())
      const message = workCommentMessage({
        taskTitle: (commented.title ?? '').toString(),
        author,
        content: (record.content ?? '').toString(),
      })
      const sent = await sendPush(admin, await tokens(admin, others), {
        ...message,
        kind: 'comment',
        notificationId: noteId(`comment:${commentTaskId}`),
        collapseId: `comment-${commentTaskId}`,
        taskId: commentTaskId,
      })
      return json({ success: true, sent, title: message.title })
    }
    const oldRecord = (body.old_record ?? {}) as Record<string, unknown>
    const taskId = (record.id ?? '').toString()
    if (!taskId || (kind !== 'added' && kind !== 'status')) {
      return json({ success: true, skipped: 'ignored' })
    }

    const stamp = (record.updated_at ?? record.created_at ?? taskId).toString()
    const dedupeKey = kind === 'added' ? `added:${taskId}` : `status:${taskId}:${record.status_id}:${stamp}`
    if (!(await claimDedupe(admin, dedupeKey))) {
      return json({ success: true, skipped: 'duplicate' })
    }

    // 시작 누르고 바로 완료하면 트리거가 두 번 온다. 잠깐 기다린 뒤 지금 상태를
    // 다시 읽어, 그사이 또 바뀌었으면 이 알림은 버리고 마지막 것만 보낸다.
    await new Promise((resolve) => setTimeout(resolve, SETTLE_MS))
    const { data: current, error: currentError } = await admin
      .from('tasks')
      .select('*')
      .eq('id', taskId)
      .maybeSingle()
    if (currentError) throw currentError
    if (!current) return json({ success: true, skipped: 'deleted' })
    const task = current as Record<string, unknown>
    if (kind === 'status') {
      if ((task.status_id ?? '').toString() !== (record.status_id ?? '').toString()) {
        return json({ success: true, skipped: 'superseded' })
      }
      // 앱 「실행 취소」로 되돌린 상태 — 바꿨던 알림은 위 superseded 로 빠지므로 둘 다 안 보낸다.
      if (await consumeSilent(admin, taskId)) {
        return json({ success: true, skipped: 'undo' })
      }
      // 추가 알림이 기다리는 동안 바뀐 상태는 그 알림이 「바로 시작」처럼 한 번에 알린다.
      const createdAt = Date.parse((task.created_at ?? '').toString())
      const updatedAt = Date.parse((record.updated_at ?? '').toString())
      const changedAt = Number.isFinite(updatedAt) ? updatedAt : Date.now() - SETTLE_MS
      if (Number.isFinite(createdAt) && changedAt - createdAt < SETTLE_MS * 0.9) {
        return json({ success: true, skipped: 'covered-by-added' })
      }
    }

    const { data: statuses } = await admin.from('task_statuses').select('id, name')
    const statusName = new Map(
      ((statuses ?? []) as Array<{ id: string; name: string }>).map((row) => [row.id, row.name]),
    )
    const { data: priorities } = await admin.from('task_priorities').select('id, name')
    const priorityName = new Map(
      ((priorities ?? []) as Array<{ id: unknown; name: string }>).map((row) => [String(row.id), row.name]),
    )
    const names = await nameMap(admin)
    const assigneeLabel = (Array.isArray(task.assignees) ? task.assignees : [])
      .map((email) => names.get((email ?? '').toString()) ?? '')
      .filter(Boolean)
      .join(', ')
    const requesterRaw = (task.requester ?? '').toString().trim()
    const enteredPrevious = Date.parse((oldRecord.updated_at ?? '').toString())
    const changedAt = Date.parse((record.updated_at ?? '').toString())
    const createdAt = Date.parse((task.created_at ?? '').toString())

    const message = workTaskMessage({
      kind: kind as 'added' | 'status',
      title: (task.title ?? '').toString(),
      status: statusName.get((task.status_id ?? '').toString()) ?? '',
      previousStatus: statusName.get((oldRecord.status_id ?? '').toString()) ?? '',
      assigneeLabel,
      requester: names.get(requesterRaw) ?? requesterRaw,
      priority: priorityName.get(String(task.priority_id ?? '')) ?? '',
      due: ymd(task.due_date),
      today: todayKst(),
      minutesInPrevious:
        Number.isFinite(enteredPrevious) && Number.isFinite(changedAt)
          ? Math.max(0, (changedAt - enteredPrevious) / 60_000)
          : null,
      minutesSinceCreated:
        Number.isFinite(createdAt) && Number.isFinite(changedAt)
          ? Math.max(0, (changedAt - createdAt) / 60_000)
          : null,
    })

    const sent = await sendPush(admin, pushTokens, {
      ...message,
      kind,
      // 같은 업무 알림은 한 칸에서 갈아끼운다 (안드로이드 id·태그, iOS collapse-id).
      notificationId: noteId(`task:${taskId}`),
      collapseId: `task-${taskId}`,
      taskId,
    })
    return json({ success: true, sent, title: message.title })
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('notify-work-task error:', message)
    return json({ error: message }, 500)
  }
})
