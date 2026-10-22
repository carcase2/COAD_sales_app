import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const LAB_GROUPS = new Set(['연구소', '관리자'])
const OPEN_STATUSES = ['접수', '진행중', '보류']

type StatusRow = { id: string; name: string }
type UserRow = {
  id: string
  name: string
  email?: string | null
  is_active?: boolean | null
  groups?: { name?: string | null } | { name?: string | null }[] | null
}

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

function groupName(groups: UserRow['groups']): string {
  if (!groups) return ''
  if (Array.isArray(groups)) return (groups[0]?.name ?? '').toString().trim()
  return (groups.name ?? '').toString().trim()
}

function asEmails(raw: unknown): string[] {
  if (!Array.isArray(raw)) return []
  return raw.map((item) => (item ?? '').toString().trim()).filter((item) => item.length > 0)
}

async function labUser(
  admin: SupabaseClient,
  userId: string,
): Promise<UserRow | null> {
  const { data, error } = await admin
    .from('users')
    .select('id, name, email, is_active, groups(name)')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  const row = data as UserRow | null
  if (!row?.id || row.is_active === false) return null
  if (!LAB_GROUPS.has(groupName(row.groups))) return null
  return row
}

async function statusMap(admin: SupabaseClient): Promise<Map<string, string>> {
  const { data, error } = await admin.from('task_statuses').select('id, name')
  if (error) throw error
  const map = new Map<string, string>()
  for (const row of (data ?? []) as StatusRow[]) {
    if (row.id && row.name) map.set(row.name, row.id)
  }
  return map
}

async function departmentId(admin: SupabaseClient): Promise<string> {
  const { data, error } = await admin
    .from('departments')
    .select('id, name, is_active')
    .eq('name', '연구소')
    .limit(5)
  if (error) throw error
  const rows = (data ?? []) as Array<{ id: string; is_active?: boolean | null }>
  const active = rows.find((row) => row.is_active !== false) ?? rows[0]
  if (!active?.id) throw new Error('연구소 부서를 찾지 못했습니다.')
  return active.id
}

async function assigneeChoices(admin: SupabaseClient): Promise<Array<{ email: string; name: string }>> {
  const { data, error } = await admin
    .from('user_roles')
    .select('user_email, display_name')
    .limit(200)
  if (error) throw error
  const people: Array<{ email: string; name: string }> = []
  const seen = new Set<string>()
  for (const row of (data ?? []) as Array<{ user_email?: string; display_name?: string }>) {
    const email = (row.user_email ?? '').trim()
    if (!email || seen.has(email)) continue
    seen.add(email)
    const name = (row.display_name ?? '').trim() || email.split('@')[0]
    people.push({ email, name })
  }
  people.sort((a, b) => a.name.localeCompare(b.name, 'ko'))
  return people
}

const PRIORITY_ORDER = ['특급', '높음', '보통', '낮음', '후순위']

function idKey(value: unknown): string {
  return (value ?? '').toString().trim()
}

function priorityValue(id: string): string | number {
  return /^\d+$/.test(id) ? Number(id) : id
}

async function priorityChoices(
  admin: SupabaseClient,
): Promise<Array<{ id: string; name: string }>> {
  const { data, error } = await admin.from('task_priorities').select('id, name')
  if (error) throw error
  const rows: Array<{ id: string; name: string }> = []
  for (const row of (data ?? []) as Array<{ id?: unknown; name?: string }>) {
    const id = idKey(row.id)
    const name = (row.name ?? '').trim()
    if (!id || !name) continue
    rows.push({ id, name })
  }
  rows.sort((a, b) => {
    const ai = PRIORITY_ORDER.indexOf(a.name)
    const bi = PRIORITY_ORDER.indexOf(b.name)
    return (ai < 0 ? 99 : ai) - (bi < 0 ? 99 : bi)
  })
  return rows
}

async function emailNames(admin: SupabaseClient): Promise<Map<string, string>> {
  const names = new Map<string, string>()
  const { data: roles, error } = await admin
    .from('user_roles')
    .select('user_email, display_name')
    .limit(500)
  if (error) throw error
  for (const row of (roles ?? []) as Array<{ user_email?: string; display_name?: string }>) {
    const email = (row.user_email ?? '').trim().toLowerCase()
    const name = (row.display_name ?? '').trim()
    if (email && name && name.toLowerCase() !== email) names.set(email, name)
  }
  const { data: users, error: userError } = await admin.from('users').select('email, name').limit(500)
  if (userError) throw userError
  for (const row of (users ?? []) as Array<{ email?: string | null; name?: string | null }>) {
    const email = (row.email ?? '').trim().toLowerCase()
    const name = (row.name ?? '').trim()
    if (!email || !name || name.toLowerCase() === email || names.has(email)) continue
    names.set(email, name)
  }
  return names
}

function personLabel(raw: string, names: Map<string, string>): string {
  const text = raw.trim()
  if (!text.includes('@')) return text
  return names.get(text.toLowerCase()) || text
}

async function loadComments(admin: SupabaseClient, taskId: string) {
  const names = await emailNames(admin)
  const { data, error } = await admin
    .from('task_comments')
    .select('id, content, author_email, created_at')
    .eq('task_id', taskId)
    .order('created_at', { ascending: true })
    .limit(200)
  if (error) throw error
  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    id: (row.id ?? '').toString(),
    content: (row.content ?? '').toString(),
    author: personLabel((row.author_email ?? '').toString(), names),
    createdAt: (row.created_at ?? '').toString(),
  }))
}

function myEmail(
  user: UserRow,
  people: Array<{ email: string; name: string }>,
): string | null {
  const direct = (user.email ?? '').trim()
  if (direct && people.some((person) => person.email === direct)) return direct
  const named = people.find((person) => person.name === (user.name ?? '').trim())
  return named?.email ?? (direct || null)
}

async function loadBoard(admin: SupabaseClient, user: UserRow) {
  const statuses = await statusMap(admin)
  const openIds = OPEN_STATUSES.map((name) => statuses.get(name)).filter(
    (id): id is string => Boolean(id),
  )
  const deptId = await departmentId(admin)
  const people = await assigneeChoices(admin)
  const priorities = await priorityChoices(admin)
  const nameByEmail = new Map(people.map((person) => [person.email, person.name]))
  const names = await emailNames(admin)
  const priorityName = new Map(priorities.map((item) => [item.id, item.name]))

  const taskSelect =
    'id, title, detail, status_id, priority_id, due_date, completed_date, assignees, requester, created_at'
  let tasks: Array<Record<string, unknown>> = []
  if (openIds.length > 0) {
    const { data, error } = await admin
      .from('tasks')
      .select(taskSelect)
      .eq('department_id', deptId)
      .in('status_id', openIds)
      .order('due_date', { ascending: true, nullsFirst: false })
      .limit(300)
    if (error) throw error
    tasks = (data ?? []) as Array<Record<string, unknown>>
  }

  // 완료는 목록에서 빼지 않는다. 오늘 완료한 업무가 달력에서 바로 사라지지 않게
  // 최근 완료 건을 남은 업무와 따로 가져온다.
  const doneId = statuses.get('완료')
  if (doneId) {
    const { data, error } = await admin
      .from('tasks')
      .select(taskSelect)
      .eq('department_id', deptId)
      .eq('status_id', doneId)
      .order('completed_date', { ascending: false, nullsFirst: false })
      .limit(400)
    if (error) throw error
    const seen = new Set(tasks.map((task) => (task.id ?? '').toString()))
    for (const row of (data ?? []) as Array<Record<string, unknown>>) {
      const id = (row.id ?? '').toString()
      if (!id || seen.has(id)) continue
      seen.add(id)
      tasks.push(row)
    }
  }

  const idToName = new Map<string, string>()
  for (const [name, id] of statuses) idToName.set(id, name)

  return {
    ok: true,
    today: todayKst(),
    myEmail: myEmail(user, people),
    assignees: people,
    priorities,
    tasks: tasks.map((task) => {
      const emails = asEmails(task.assignees)
      const priorityId = idKey(task.priority_id)
      return {
        id: task.id,
        title: (task.title ?? '').toString(),
        detail: (task.detail ?? '').toString(),
        status: idToName.get((task.status_id ?? '').toString()) ?? '',
        dueDate: (task.due_date ?? '').toString(),
        completedDate: (task.completed_date ?? '').toString(),
        requester: personLabel((task.requester ?? '').toString(), names),
        createdAt: (task.created_at ?? '').toString(),
        priorityId,
        priority: priorityName.get(priorityId) ?? '',
        assigneeEmails: emails,
        assigneeNames: emails.map((email) => nameByEmail.get(email) ?? email.split('@')[0]),
      }
    }),
  }
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') return json({ ok: false, error: 'POST만 받을 수 있습니다.' }, 405)
    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>
    const userId = (body.userId ?? '').toString().trim()
    const action = (body.action ?? 'list').toString().trim()
    if (!userId) return json({ ok: false, error: '계정을 확인할 수 없습니다.' }, 400)

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const user = await labUser(admin, userId)
    if (!user) return json({ ok: false, error: '연구소와 관리자만 업무를 볼 수 있습니다.' }, 403)

    if (action === 'list') {
      return json(await loadBoard(admin, user))
    }

    const statuses = await statusMap(admin)
    const deptId = await departmentId(admin)
    const today = todayKst()

    if (action === 'create') {
      const title = (body.title ?? '').toString().trim()
      const assigneeEmail = (body.assigneeEmail ?? '').toString().trim()
      const detail = (body.detail ?? '').toString().trim()
      const dueRaw = (body.dueDate ?? '').toString().trim()
      if (!title) return json({ ok: false, error: '제목을 입력해 주세요.' }, 400)
      if (!assigneeEmail) return json({ ok: false, error: '담당자를 선택해 주세요.' }, 400)
      const people = await assigneeChoices(admin)
      if (!people.some((person) => person.email === assigneeEmail)) {
        return json({ ok: false, error: '담당자를 다시 선택해 주세요.' }, 400)
      }
      const received = statuses.get('접수')
      if (!received) return json({ ok: false, error: '접수 상태를 찾지 못했습니다.' }, 500)
      const dueDate = /^\d{4}-\d{2}-\d{2}$/.test(dueRaw) ? dueRaw : null
      const priorities = await priorityChoices(admin)
      const wanted = idKey(body.priorityId)
      const chosen =
        priorities.find((item) => item.id === wanted) ??
        priorities.find((item) => item.name === '보통')
      const { data: types } = await admin.from('task_types').select('id, name').eq('name', '기타').limit(1)
      const typeId = (types?.[0] as { id?: string } | undefined)?.id ?? null
      const { error } = await admin.from('tasks').insert({
        title,
        detail,
        assignees: [assigneeEmail],
        requester: personLabel((user.name ?? '').trim(), await emailNames(admin)),
        status_id: received,
        priority_id: chosen ? priorityValue(chosen.id) : 2,
        type_id: typeId,
        department_id: deptId,
        department: '연구소',
        due_date: dueDate,
        start_date: null,
        completed_date: null,
      })
      if (error) throw error
      return json(await loadBoard(admin, user))
    }

    const taskId = (body.taskId ?? '').toString().trim()
    if (!taskId) return json({ ok: false, error: '업무를 찾지 못했습니다.' }, 400)

    if (action === 'comments' || action === 'addComment') {
      const { data: current, error: readError } = await admin
        .from('tasks')
        .select('id, department_id')
        .eq('id', taskId)
        .maybeSingle()
      if (readError) throw readError
      if (!current || current.department_id !== deptId) {
        return json({ ok: false, error: '업무를 찾지 못했습니다.' }, 404)
      }
      if (action === 'addComment') {
        const content = (body.content ?? '').toString().trim()
        if (!content) return json({ ok: false, error: '댓글을 입력해 주세요.' }, 400)
        if (content.length > 2000) {
          return json({ ok: false, error: '댓글은 2000자까지 쓸 수 있습니다.' }, 400)
        }
        const people = await assigneeChoices(admin)
        const email = (myEmail(user, people) ?? (user.email ?? '')).trim()
        if (!email) return json({ ok: false, error: '댓글 작성자의 메일을 찾지 못했습니다.' }, 400)
        const { error } = await admin.from('task_comments').insert({
          task_id: taskId,
          author_email: email,
          content,
        })
        if (error) throw error
      }
      return json({ ok: true, comments: await loadComments(admin, taskId) })
    }

    const nextName =
      action === 'start' ? '진행중' : action === 'complete' ? '완료' : action === 'hold' ? '보류' : ''
    if (!nextName) return json({ ok: false, error: '알 수 없는 동작입니다.' }, 400)
    const nextId = statuses.get(nextName)
    if (!nextId) return json({ ok: false, error: `${nextName} 상태를 찾지 못했습니다.` }, 500)

    const { data: current, error: readError } = await admin
      .from('tasks')
      .select('id, status_id, start_date, department_id')
      .eq('id', taskId)
      .maybeSingle()
    if (readError) throw readError
    if (!current || current.department_id !== deptId) {
      return json({ ok: false, error: '업무를 찾지 못했습니다.' }, 404)
    }
    if (current.status_id === nextId) return json(await loadBoard(admin, user))

    const patch: Record<string, unknown> = { status_id: nextId }
    if (action === 'start') {
      patch.start_date = (current.start_date ?? '').toString().trim() || today
      patch.completed_date = null
    } else if (action === 'complete') {
      patch.completed_date = today
      patch.start_date = (current.start_date ?? '').toString().trim() || today
    }
    const { error: updateError } = await admin.from('tasks').update(patch).eq('id', taskId)
    if (updateError) throw updateError
    return json(await loadBoard(admin, user))
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('work-tasks error:', message)
    return json({ ok: false, error: '업무를 처리하지 못했습니다.' }, 500)
  }
})
