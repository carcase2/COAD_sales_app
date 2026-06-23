-- v0.18.8: 발급 알림 수신 대상 개선 (이상수 팀장 요청)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.8',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청·완료 알림이 관리자 전체와 해당 건 담당자에게만 전달되도록 개선했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.8'
);

update public.app_update_policy
set
  latest_version = '0.18.8',
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
  '0.18.8',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
