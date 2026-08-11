-- v1.3.2: 상담 입력 시트 UX (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.3.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담내용 입력 시 키보드에 가려지지 않도록 시트·입력란 레이아웃을 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '여러 줄 상담 내용을 입력하면서 윗줄을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.3.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담내용 입력 시 키보드에 가려지지 않도록 시트·입력란 레이아웃을 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '여러 줄 상담 내용을 입력하면서 윗줄을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.3.2';

update public.app_update_policy
set
  latest_version = '1.3.2',
  updated_at = now()
where is_active = true;
