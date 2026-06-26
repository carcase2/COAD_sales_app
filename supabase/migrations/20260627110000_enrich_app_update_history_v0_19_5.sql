-- v0.19.5 업데이트 내역 보강 (본사일반 FCM 전체 기능 포함)

update public.app_update_history
set
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 일정 등록·수정·삭제 시 본사영업·관리자에게 FCM 푸시 알림이 갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림 제목에 [본사일반]·현장명이 표시됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림 본문에 현장·입력자·이달 남은 빈 칸·가장 빠른 빈 칸 날짜가 표시됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림을 탭하면 본사일반 일정 화면으로 이동합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '일정 저장 후 FCM 전송 안정성을 개선했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  proposer = '김경덕 이사'
where version = '0.19.5';
