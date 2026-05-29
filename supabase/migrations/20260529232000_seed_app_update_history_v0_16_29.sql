-- v0.16.29: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.29',
  '이상수 팀장',
  jsonb_build_array(
    '발급요청 탭·메뉴에 (TEST) 표시',
    '업데이트 내역 제안자 표기 정리 (이상수 팀장)'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.29'
);

update public.app_update_policy
set
  latest_version = '0.16.29',
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
  '0.16.29',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
