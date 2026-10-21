-- v1.14.5: 연구소·관리자 업무 탭 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '연구소와 관리자 홈에 업무 탭이 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무는 달력으로 보고, 월간과 주간을 바꿀 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자를 고르면 그 사람 업무만 달력에 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '날짜를 누르면 그 날 업무를 보고 추가할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무를 누르면 상세와 만든 날짜, 댓글을 보고 시작·보류·완료할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '남은 업무, 오늘 마감, 업무 추가와 상태 변경 때 알림이 옵니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.5'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '연구소와 관리자 홈에 업무 탭이 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무는 달력으로 보고, 월간과 주간을 바꿀 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자를 고르면 그 사람 업무만 달력에 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '날짜를 누르면 그 날 업무를 보고 추가할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무를 누르면 상세와 만든 날짜, 댓글을 보고 시작·보류·완료할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '남은 업무, 오늘 마감, 업무 추가와 상태 변경 때 알림이 옵니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.5';

update public.app_update_policy
set
  latest_version = '1.14.5',
  updated_at = now()
where is_active = true;
