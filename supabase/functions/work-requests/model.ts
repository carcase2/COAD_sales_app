// 부서 사이 업무 요청 규칙 — COAD_home src/features/work/utils/workRequestModel.ts 와 같다.
// 웹과 앱이 같은 work_requests 표를 쓰므로 둘 중 하나만 바꾸면 안 된다.

export const REQUEST_PRIORITIES = ['후순위', '낮음', '보통', '높음', '긴급', '특급'] as const
export const REQUEST_STATUSES = ['요청', '수락', '거절', '보류'] as const
export const REQUEST_PROGRESS = ['접수', '진행중', '완료'] as const

export type RequestStatus = (typeof REQUEST_STATUSES)[number]
export type RequestProgress = '' | (typeof REQUEST_PROGRESS)[number]
export type RequestDecision = 'accept' | 'reject' | 'hold'

export type RequestRow = {
  id: string
  title: string
  detail: string
  from_group: string
  to_group: string
  requester_name: string
  requester_user_id: string
  due_date: string | null
  priority_name: string
  status: RequestStatus
  progress: RequestProgress
  response_note: string
  responded_by: string
  responded_at: string | null
  created_at: string
  updated_at: string
}

export type Actor = { id: string; name: string; groupName: string }

const SEE_ALL = new Set(['관리자', '시스템관리자'])

export function seesAllRequestGroups(groupName: string): boolean {
  return SEE_ALL.has(groupName.trim())
}

/** 요청할 수 있는 부서 — 내 부서와 관리자 그룹은 뺀다. */
export function requestTargets(groupNames: string[], fromGroup: string): string[] {
  const from = fromGroup.trim()
  return [...new Set(groupNames.map((name) => name.trim()).filter(Boolean))]
    .filter((name) => name !== from && !seesAllRequestGroups(name))
    .sort((a, b) => a.localeCompare(b, 'ko'))
}

export function canDecideRequest(row: Pick<RequestRow, 'to_group'>, actor: Pick<Actor, 'groupName'>): boolean {
  if (seesAllRequestGroups(actor.groupName)) return true
  const group = actor.groupName.trim()
  return group !== '' && group === row.to_group
}

export function canCancelRequest(
  row: Pick<RequestRow, 'status' | 'from_group' | 'requester_user_id'>,
  actor: Pick<Actor, 'id' | 'groupName'>,
): boolean {
  if (row.status !== '요청') return false
  if (seesAllRequestGroups(actor.groupName)) return true
  if (actor.id && actor.id === row.requester_user_id) return true
  const group = actor.groupName.trim()
  return group !== '' && group === row.from_group
}

/** 요청자가 아직 받기 전(요청·보류)이면 제목·내용·기한·우선순위를 고칠 수 있다. */
export function canEditRequest(
  row: Pick<RequestRow, 'status' | 'from_group' | 'requester_user_id'>,
  actor: Pick<Actor, 'id' | 'groupName'>,
): boolean {
  if (row.status !== '요청' && row.status !== '보류') return false
  if (seesAllRequestGroups(actor.groupName)) return true
  if (actor.id && actor.id === row.requester_user_id) return true
  const group = actor.groupName.trim()
  return group !== '' && group === row.from_group
}

function started(row: Pick<RequestRow, 'progress'>): boolean {
  return row.progress === '진행중' || row.progress === '완료'
}

export function decisionPatch(
  row: Pick<RequestRow, 'status' | 'progress'>,
  action: RequestDecision,
): { status: RequestStatus; progress: RequestProgress } | { error: string } {
  if (started(row)) return { error: '진행이 시작된 요청은 수락, 거절, 보류를 바꿀 수 없습니다.' }
  if (action === 'accept') return { status: '수락', progress: '접수' }
  if (action === 'reject') return { status: '거절', progress: '' }
  return { status: '보류', progress: '' }
}

export function progressPatch(
  row: Pick<RequestRow, 'status'>,
  progress: string,
): { progress: RequestProgress } | { error: string } {
  if (row.status !== '수락') return { error: '수락된 요청만 진행을 바꿀 수 있습니다.' }
  if (progress !== '접수' && progress !== '진행중' && progress !== '완료') {
    return { error: '진행 상태를 확인해 주세요.' }
  }
  return { progress }
}

export function cleanDate(value: unknown): string | null | undefined {
  const text = (value ?? '').toString().trim()
  if (!text) return null
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : undefined
}
