-- v0.16.30: 접수 하단 메뉴 + 홈 통계 가림 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.30',
  '개발팀',
  jsonb_build_array(
    '접수 등록을 하단 메뉴(홈·접수·발급요청)로 이동',
    '홈 통계(초기응답 평균 등) 버튼 가림 개선',
    '발급요청 탭에서도 바로 접수 등록 가능'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.30'
);

update public.app_update_policy
set
  latest_version = '0.16.30',
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
  '0.16.30',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
