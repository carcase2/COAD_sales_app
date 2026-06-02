-- v0.16.31: 흐름 화면 사용성 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.31',
  '개발팀',
  jsonb_build_array(
    '흐름 화면 상단 기간 선택/날짜 영역 가독성 개선',
    '접수 탭 탭/롱프레스 동작 분리(탭=바로 접수, 길게=퀵메뉴)',
    '흐름 지표 표현 단순화 및 텍스트 개선'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.31'
);

update public.app_update_policy
set
  latest_version = '0.16.31',
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
  '0.16.31',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
