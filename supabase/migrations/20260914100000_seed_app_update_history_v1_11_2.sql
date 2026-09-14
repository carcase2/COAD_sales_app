-- v1.11.2: 본사일반·대구지사 달력 당겨서 새로고침 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.11.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반·대구지사 달력을 아래로 당기면 일정이 새로고침됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.11.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반·대구지사 달력을 아래로 당기면 일정이 새로고침됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.11.2';

update public.app_update_policy
set
  latest_version = '1.11.2',
  updated_at = now()
where is_active = true;
