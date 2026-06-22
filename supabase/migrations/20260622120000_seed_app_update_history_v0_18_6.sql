-- v0.18.6: 상담내용 길게 눌러 복사

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.6',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '통화 상세 상담 이력에서 상담내용을 길게 누르면 복사할 수 있습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.6'
);

update public.app_update_policy
set
  latest_version = '0.18.6',
  updated_at = now()
where is_active = true;

insert into public.app_update_policy (
  min_version,
  latest_version,
  store_url,
  force_update,
  is_active,
  updated_at
)
select
  '0.16.0',
  '0.18.6',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
