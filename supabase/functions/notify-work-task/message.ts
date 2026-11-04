// 업무 알림 문구 — 상태 전이(이전 → 지금)별로 나눈다. 네트워크 없는 순수 함수.

export type WorkTaskEvent = {
  kind: 'added' | 'status'
  title: string
  /** 지금 상태 이름 (접수·진행중·완료·보류). */
  status: string
  /** 바뀌기 전 상태 이름. 추가 알림이면 빈 값. */
  previousStatus: string
  assigneeLabel: string
  requester: string
  priority: string
  due: string
  today: string
  /** 이전 상태로 들어간 뒤 지금 상태가 되기까지 걸린 분. 모르면 null. */
  minutesInPrevious: number | null
  /** 업무를 만든(접수한) 뒤 지금 상태가 되기까지 걸린 분. 모르면 null. */
  minutesSinceCreated: number | null
}

/** task_priorities 이름 (낮음·보통·높음·특급·후순위) 중 본문 앞에 표시할 것. */
const URGENT_PRIORITIES = new Set(['특급', '높음'])

function daysBetween(fromYmd: string, toYmd: string): number {
  const from = Date.parse(`${fromYmd}T00:00:00Z`)
  const to = Date.parse(`${toYmd}T00:00:00Z`)
  return Math.round((to - from) / 86_400_000)
}

/** 마감 표시 — 오늘 마감 · 마감 n일 지남 · 마감 MM-DD (D-n). */
export function dueLabel(due: string, today: string): string {
  if (!due) return ''
  if (due === today) return '오늘 마감'
  const left = daysBetween(today, due)
  if (left < 0) return `마감 ${-left}일 지남`
  return `마감 ${due.slice(5)} (D-${left})`
}

/** 완료 시 마감 대비 — 마감 n일 전 완료 · 마감일 완료 · 마감 n일 지나 완료. */
function completedAgainstDue(due: string, today: string): string {
  if (!due) return ''
  const left = daysBetween(today, due)
  if (left > 0) return `마감 ${left}일 전 완료`
  if (left === 0) return '마감일 완료'
  return `마감 ${-left}일 지나 완료`
}

/** 걸린 시간 — 3분 · 2시간 · 4일. */
export function elapsedLabel(minutes: number): string {
  if (minutes < 1) return '1분 안'
  if (minutes < 60) return `${Math.round(minutes)}분`
  if (minutes < 60 * 24) return `${Math.round(minutes / 60)}시간`
  return `${Math.round(minutes / (60 * 24))}일`
}

function headlineFor(event: WorkTaskEvent): string {
  const { kind, status, previousStatus } = event
  if (kind === 'added') {
    if (status === '진행중') return '새 업무 · 바로 시작'
    if (status === '완료') return '새 업무 · 바로 완료'
    if (status === '보류') return '새 업무 · 보류'
    return '새 업무'
  }
  switch (status) {
    case '진행중':
      if (previousStatus === '보류') return '업무 재개'
      if (previousStatus === '완료') return '업무 다시 진행'
      return '업무 시작'
    case '완료':
      return '업무 완료'
    case '보류':
      return '업무 보류'
    case '접수':
      return previousStatus ? `업무 ${previousStatus} → 접수로 되돌림` : '업무 접수로 되돌림'
    default:
      return '업무 상태 변경'
  }
}

/** 알림 제목·본문. 제목에 담당을, 본문 첫 줄에 업무 제목을 둔다. */
export function workTaskMessage(event: WorkTaskEvent): { title: string; body: string } {
  const headline = headlineFor(event)
  const title = event.assigneeLabel ? `${headline} · ${event.assigneeLabel}` : headline
  const urgent = URGENT_PRIORITIES.has(event.priority) ? `[${event.priority}] ` : ''
  const name = event.title.trim() || '제목 없음'

  const bits: string[] = []
  const sinceCreated = event.minutesSinceCreated
  const waited = sinceCreated != null && sinceCreated >= 1 ? elapsedLabel(sinceCreated) : ''
  if (event.kind === 'added') {
    if (event.requester) bits.push(`요청 ${event.requester}`)
    // 바로 완료로 올린 업무는 남은 마감이 아니라 마감 대비 언제 끝냈는지.
    bits.push(
      event.status === '완료'
        ? completedAgainstDue(event.due, event.today)
        : dueLabel(event.due, event.today),
    )
  } else if (event.status === '완료') {
    const took = event.minutesInPrevious
    if (event.previousStatus === '진행중' && took != null && took >= 1) {
      bits.push(`시작 후 ${elapsedLabel(took)} 만에 완료`)
    } else if (waited && (event.previousStatus === '접수' || event.previousStatus === '진행중')) {
      // 접수에서 바로 완료, 또는 시작과 동시에 완료 — 접수부터 센다.
      bits.push(`접수 후 ${waited} 만에 완료`)
    } else if (event.previousStatus === '진행중' && took != null) {
      bits.push('시작 직후 완료')
    }
    bits.push(completedAgainstDue(event.due, event.today))
  } else if (event.status === '진행중' && event.previousStatus === '접수') {
    if (waited) bits.push(`접수 후 ${waited} 만에 시작`)
    bits.push(dueLabel(event.due, event.today))
  } else if (event.status === '보류' && event.previousStatus === '진행중' && event.minutesInPrevious != null) {
    bits.push(`진행 ${elapsedLabel(event.minutesInPrevious)} 뒤 보류`)
    bits.push(dueLabel(event.due, event.today))
  } else {
    bits.push(dueLabel(event.due, event.today))
  }

  const detail = bits.filter(Boolean).join(' · ')
  return { title, body: [`${urgent}${name}`, detail].filter(Boolean).join('\n') }
}
