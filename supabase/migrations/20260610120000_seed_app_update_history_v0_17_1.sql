-- v0.17.1: 발급요청 등록 알림 복구

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.17.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청 등록 시 푸시·로컬 알림 복구',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.17.1'
);

update public.app_update_policy
set
  latest_version = '0.17.1',
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
  '0.17.1',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
