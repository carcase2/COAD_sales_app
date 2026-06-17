-- v0.17.4: 발급 완료 푸시·알림 탭 상세 이동

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.17.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급 완료 푸시 알림 및 알림 탭 시 세부내용 이동',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.17.4'
);

update public.app_update_policy
set
  latest_version = '0.17.4',
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
  '0.17.4',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
