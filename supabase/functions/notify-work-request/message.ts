// 부서 요청 알림 — 누가 받는지와 문구. 네트워크 없는 순수 함수.

export type RequestRecord = {
  id?: string
  title?: string
  from_group?: string
  to_group?: string
  requester_name?: string
  requester_user_id?: string
  due_date?: string | null
  priority_name?: string
  status?: string
  progress?: string
  response_note?: string
  responded_by?: string
  updated_at?: string
}

export type RequestPush =
  | { audience: 'group'; group: string; excludeUserId: string; title: string; body: string; key: string }
  | { audience: 'user'; userId: string; title: string; body: string; key: string }

const URGENT = new Set(['특급', '긴급', '높음'])

function daysBetween(fromYmd: string, toYmd: string): number {
  const from = Date.parse(`${fromYmd}T00:00:00Z`)
  const to = Date.parse(`${toYmd}T00:00:00Z`)
  return Math.round((to - from) / 86_400_000)
}

export function requestDueLabel(due: string, today: string): string {
  if (!due) return ''
  if (due === today) return '오늘까지'
  const left = daysBetween(today, due)
  if (left < 0) return `기한 ${-left}일 지남`
  return `${due.slice(5).replace('-', '/')}까지 (D-${left})`
}

function titleLine(record: RequestRecord): string {
  const priority = (record.priority_name ?? '').trim()
  const urgent = URGENT.has(priority) ? `[${priority}] ` : ''
  return `${urgent}${(record.title ?? '').trim() || '제목 없음'}`
}

/**
 * INSERT → 받는 부서 전원. 수락·거절·보류·진행 변화 → 요청한 사람.
 * 알릴 것이 없으면 null.
 */
export function requestPush(
  op: 'INSERT' | 'UPDATE',
  record: RequestRecord,
  old: RequestRecord,
  today: string,
): RequestPush | null {
  const id = (record.id ?? '').trim()
  if (!id) return null
  const due = (record.due_date ?? '').toString().slice(0, 10)

  if (op === 'INSERT') {
    const group = (record.to_group ?? '').trim()
    if (!group) return null
    const who = [record.from_group, record.requester_name].map((v) => (v ?? '').trim()).filter(Boolean).join(' ')
    return {
      audience: 'group',
      group,
      excludeUserId: (record.requester_user_id ?? '').trim(),
      title: `업무 요청 · ${(record.from_group ?? '').trim() || '다른 부서'}`,
      body: [titleLine(record), [who ? `요청 ${who}` : '', requestDueLabel(due, today)].filter(Boolean).join(' · ')]
        .filter(Boolean)
        .join('\n'),
      key: `request:added:${id}`,
    }
  }

  const userId = (record.requester_user_id ?? '').trim()
  if (!userId) return null
  const status = (record.status ?? '').trim()
  const progress = (record.progress ?? '').trim()
  const toGroup = (record.to_group ?? '').trim() || '받은 부서'
  const note = (record.response_note ?? '').trim()
  const by = (record.responded_by ?? '').trim()

  let headline = ''
  let detail = ''
  if (status !== (old.status ?? '').trim()) {
    if (status === '수락') headline = '요청 수락'
    else if (status === '거절') headline = '요청 거절'
    else if (status === '보류') headline = '요청 보류'
    else return null
    detail = [by ? `처리 ${by}` : '', note ? `메모 ${note}` : ''].filter(Boolean).join(' · ')
  } else if (progress !== (old.progress ?? '').trim()) {
    if (progress === '진행중') headline = '요청 진행 시작'
    else if (progress === '완료') headline = '요청 완료'
    else return null
    detail = progress === '완료' ? '' : requestDueLabel(due, today)
  } else {
    return null
  }

  return {
    audience: 'user',
    userId,
    title: `${headline} · ${toGroup}`,
    body: [titleLine(record), detail].filter(Boolean).join('\n'),
    key: `request:${id}:${status}:${progress}:${(record.updated_at ?? '').trim()}`,
  }
}
