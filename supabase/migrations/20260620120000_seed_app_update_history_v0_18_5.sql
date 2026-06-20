-- v0.18.5: 고객전화 접수 삭제

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '통화 상세 화면에서 잘못 등록한 고객전화 접수를 삭제할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.5'
);

update public.app_update_policy
set
  latest_version = '0.18.5',
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
  '0.18.5',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
