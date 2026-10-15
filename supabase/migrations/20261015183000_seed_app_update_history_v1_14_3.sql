-- v1.14.3: 미수주 사유에 상담내용 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객전화에서 상담내용을 먼저 적은 뒤 미수주를 누르면, 그 글이 미수주 사유에 들어갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단순문의·설계문의는 상담내용이 그대로 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.3'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객전화에서 상담내용을 먼저 적은 뒤 미수주를 누르면, 그 글이 미수주 사유에 들어갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단순문의·설계문의는 상담내용이 그대로 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.3';

update public.app_update_policy
set
  latest_version = '1.14.3',
  updated_at = now()
where is_active = true;
