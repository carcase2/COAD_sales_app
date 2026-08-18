-- v1.4.4: 상담 예정일 바로 적용 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.4.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담 예정일을 고르면 확인 창 없이 바로 적용됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '그날 이미 예정된 건수는 입력 화면에 그대로 표시됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.4.4'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담 예정일을 고르면 확인 창 없이 바로 적용됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '그날 이미 예정된 건수는 입력 화면에 그대로 표시됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.4.4';

update public.app_update_policy
set
  latest_version = '1.4.4',
  updated_at = now()
where is_active = true;
