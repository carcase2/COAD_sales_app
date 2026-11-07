import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  type Actor,
  canCancelRequest,
  canDecideRequest,
  canEditRequest,
  cleanDate,
  decisionPatch,
  progressPatch,
  REQUEST_PRIORITIES,
  type RequestDecision,
  type RequestRow,
  requestTargets,
  seesAllRequestGroups,
} from './model.ts'

// 부서 사이 업무 요청. COAD_home /api/work-request 와 같은 work_requests 표·규칙을 쓴다.
// 그룹이 있는 활성 계정이면 누구나 쓴다 (업무관리 탭과 달리 연구소만이 아니다).

const COLUMNS =
  'id, title, detail, from_group, to_group, requester_name, requester_user_id, due_date, priority_name, status, progress, response_note, responded_by, responded_at, created_at, updated_at'

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

async function actorOf(admin: SupabaseClient, userId: string): Promise<Actor | null> {
  const { data, error } = await admin
    .from('users')
    .select('id, name, is_active, groups(name)')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  const row = data as { id?: string; name?: string; is_active?: boolean | null; groups?: unknown } | null
  if (!row?.id || row.is_active === false) return null
  return {
    id: String(row.id),
    name: (row.name ?? '').toString().trim() || String(row.id),
    groupName: groupName(row.groups),
  }
}

async function allGroups(admin: SupabaseClient): Promise<string[]> {
  const { data, error } = await admin.from('groups').select('name').order('name')
  if (error) throw error
  return ((data ?? []) as Array<{ name?: string }>)
    .map((row) => (row.name ?? '').toString().trim())
    .filter(Boolean)
}

function asRow(raw: Record<string, unknown>): RequestRow {
  const text = (value: unknown) => (value ?? '').toString()
  const due = text(raw.due_date).trim()
  return {
    id: text(raw.id),
    title: text(raw.title),
    detail: text(raw.detail),
    from_group: text(raw.from_group),
    to_group: text(raw.to_group),
    requester_name: text(raw.requester_name),
    requester_user_id: text(raw.requester_user_id),
    due_date: due ? due.slice(0, 10) : null,
    priority_name: text(raw.priority_name) || '보통',
    status: text(raw.status) as RequestRow['status'],
    progress: text(raw.progress) as RequestRow['progress'],
    response_note: text(raw.response_note),
    responded_by: text(raw.responded_by),
    responded_at: raw.responded_at ? text(raw.responded_at) : null,
    created_at: text(raw.created_at),
    updated_at: text(raw.updated_at),
  }
}

function forApp(row: RequestRow, actor: Actor) {
  return {
    id: row.id,
    title: row.title,
    detail: row.detail,
    fromGroup: row.from_group,
    toGroup: row.to_group,
    requesterName: row.requester_name,
    requesterUserId: row.requester_user_id,
    dueDate: row.due_date ?? '',
    priority: row.priority_name,
    status: row.status,
    progress: row.progress,
    responseNote: row.response_note,
    respondedBy: row.responded_by,
    respondedAt: row.responded_at ?? '',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    canDecide: canDecideRequest(row, actor),
    canCancel: canCancelRequest(row, actor),
    canEdit: canEditRequest(row, actor),
  }
}

async function visibleRows(admin: SupabaseClient, actor: Actor): Promise<RequestRow[]> {
  if (seesAllRequestGroups(actor.groupName)) {
    const { data, error } = await admin
      .from('work_requests')
      .select(COLUMNS)
      .order('created_at', { ascending: false })
      .limit(300)
    if (error) throw error
    return ((data ?? []) as Array<Record<string, unknown>>).map(asRow)
  }
  const group = actor.groupName
  const [sent, received] = await Promise.all([
    admin.from('work_requests').select(COLUMNS).eq('from_group', group).order('created_at', { ascending: false }).limit(200),
    admin.from('work_requests').select(COLUMNS).eq('to_group', group).order('created_at', { ascending: false }).limit(200),
  ])
  if (sent.error) throw sent.error
  if (received.error) throw received.error
  const merged = new Map<string, RequestRow>()
  for (const raw of [...(sent.data ?? []), ...(received.data ?? [])] as Array<Record<string, unknown>>) {
    const row = asRow(raw)
    merged.set(row.id, row)
  }
  return [...merged.values()]
}

async function board(admin: SupabaseClient, actor: Actor) {
  const [groups, rows] = await Promise.all([allGroups(admin), visibleRows(admin, actor)])
  return {
    ok: true,
    today: todayKst(),
    viewer: {
      id: actor.id,
      name: actor.name,
      groupName: actor.groupName,
      seeAll: seesAllRequestGroups(actor.groupName),
    },
    targets: requestTargets(groups, actor.groupName),
    priorities: [...REQUEST_PRIORITIES],
    requests: rows.map((row) => forApp(row, actor)),
  }
}

function validText(title: string, detail: string): string | null {
  if (!title) return '제목을 입력해 주세요.'
  if (title.length > 120) return '제목은 120자까지 입력할 수 있습니다.'
  if (detail.length > 2000) return '내용은 2000자까지 입력할 수 있습니다.'
  return null
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
    const actor = await actorOf(admin, userId)
    if (!actor) return json({ ok: false, error: '로그인이 필요합니다.' }, 401)

    if (action === 'list') return json(await board(admin, actor))

    if (action === 'create') {
      if (!actor.groupName) return json({ ok: false, error: '부서가 없어 요청할 수 없습니다.' }, 400)
      const title = (body.title ?? '').toString().trim()
      const detail = (body.detail ?? '').toString().trim()
      const toGroup = (body.toGroup ?? '').toString().trim()
      const priority = (body.priority ?? '보통').toString().trim() || '보통'
      const due = cleanDate(body.dueDate)
      const invalid = validText(title, detail)
      if (invalid) return json({ ok: false, error: invalid }, 400)
      if (due === undefined) return json({ ok: false, error: '기한 형식을 확인해 주세요.' }, 400)
      if (!(REQUEST_PRIORITIES as readonly string[]).includes(priority)) {
        return json({ ok: false, error: '우선순위를 확인해 주세요.' }, 400)
      }
      const targets = requestTargets(await allGroups(admin), actor.groupName)
      if (!targets.includes(toGroup)) return json({ ok: false, error: '요청할 부서를 다시 골라 주세요.' }, 400)
      const { error } = await admin.from('work_requests').insert({
        title,
        detail,
        from_group: actor.groupName,
        to_group: toGroup,
        requester_name: actor.name.slice(0, 40),
        requester_user_id: actor.id,
        due_date: due,
        priority_name: priority,
        status: '요청',
        progress: '',
        updated_at: new Date().toISOString(),
      })
      if (error) throw error
      return json(await board(admin, actor))
    }

    const id = (body.requestId ?? '').toString().trim()
    if (!/^[0-9a-f-]{36}$/i.test(id)) return json({ ok: false, error: '요청을 찾지 못했습니다.' }, 404)
    const { data: found, error: findError } = await admin
      .from('work_requests')
      .select(COLUMNS)
      .eq('id', id)
      .maybeSingle()
    if (findError) throw findError
    if (!found) return json({ ok: false, error: '요청을 찾지 못했습니다.' }, 404)
    const row = asRow(found as Record<string, unknown>)
    const now = new Date().toISOString()

    if (action === 'cancel') {
      if (!canCancelRequest(row, actor)) return json({ ok: false, error: '이 요청을 취소할 수 없습니다.' }, 403)
      const { error } = await admin.from('work_requests').delete().eq('id', id)
      if (error) throw error
      return json(await board(admin, actor))
    }

    if (action === 'update') {
      if (!canEditRequest(row, actor)) {
        return json({ ok: false, error: '받은 부서가 수락한 뒤에는 고칠 수 없습니다.' }, 403)
      }
      const patch: Record<string, unknown> = {}
      const title = typeof body.title === 'string' ? body.title.trim() : row.title
      const detail = typeof body.detail === 'string' ? body.detail.trim() : row.detail
      const invalid = validText(title, detail)
      if (invalid) return json({ ok: false, error: invalid }, 400)
      if (title !== row.title) patch.title = title
      if (detail !== row.detail) patch.detail = detail
      if (typeof body.dueDate === 'string') {
        const due = cleanDate(body.dueDate)
        if (due === undefined) return json({ ok: false, error: '기한 형식을 확인해 주세요.' }, 400)
        patch.due_date = due
      }
      if (typeof body.priority === 'string') {
        const priority = body.priority.trim()
        if (!(REQUEST_PRIORITIES as readonly string[]).includes(priority)) {
          return json({ ok: false, error: '우선순위를 확인해 주세요.' }, 400)
        }
        patch.priority_name = priority
      }
      if (Object.keys(patch).length > 0) {
        // 보류된 요청을 고치면 받은 부서가 다시 보도록 「요청」으로 돌린다.
        if (row.status === '보류') patch.status = '요청'
        patch.updated_at = now
        const { error } = await admin.from('work_requests').update(patch).eq('id', id)
        if (error) throw error
      }
      return json(await board(admin, actor))
    }

    if (action === 'accept' || action === 'reject' || action === 'hold') {
      if (!canDecideRequest(row, actor)) return json({ ok: false, error: '받은 부서만 처리할 수 있습니다.' }, 403)
      const patch = decisionPatch(row, action as RequestDecision)
      if ('error' in patch) return json({ ok: false, error: patch.error }, 400)
      const note = (body.note ?? '').toString().trim()
      if (note.length > 500) return json({ ok: false, error: '메모는 500자까지 입력할 수 있습니다.' }, 400)
      const { error } = await admin
        .from('work_requests')
        .update({
          ...patch,
          response_note: action === 'accept' ? (note || row.response_note) : note,
          responded_by: actor.name.slice(0, 40),
          responded_at: now,
          updated_at: now,
        })
        .eq('id', id)
      if (error) throw error
      return json(await board(admin, actor))
    }

    if (action === 'progress') {
      if (!canDecideRequest(row, actor)) return json({ ok: false, error: '받은 부서만 진행을 바꿀 수 있습니다.' }, 403)
      const patch = progressPatch(row, (body.progress ?? '').toString().trim())
      if ('error' in patch) return json({ ok: false, error: patch.error }, 400)
      const { error } = await admin
        .from('work_requests')
        .update({ progress: patch.progress, updated_at: now })
        .eq('id', id)
      if (error) throw error
      return json(await board(admin, actor))
    }

    return json({ ok: false, error: '알 수 없는 동작입니다.' }, 400)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('work-requests error:', message)
    return json({ ok: false, error: '업무 요청을 처리하지 못했습니다.' }, 500)
  }
})
