-- v1.4.1: 상담 예정일 건수 안내 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.4.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담내용 입력 시 다음 예정일을 고르면 그날 이미 예정된 건수를 보여줍니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '건수를 확인한 뒤 이 날짜로 두거나 다른 날을 다시 선택할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.4.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담내용 입력 시 다음 예정일을 고르면 그날 이미 예정된 건수를 보여줍니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '건수를 확인한 뒤 이 날짜로 두거나 다른 날을 다시 선택할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.4.1';

update public.app_update_policy
set
  latest_version = '1.4.1',
  updated_at = now()
where is_active = true;
