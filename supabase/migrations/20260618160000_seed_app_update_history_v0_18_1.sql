-- v0.18.1: 이행증권 종류 칩 표시

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '금일 발급완료·발급 목록 카드에 이행증권 종류(계약이행/선급금/하자이행) 색상 칩 표시',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.1'
);

update public.app_update_policy
set
  latest_version = '0.18.1',
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
  '0.18.1',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
