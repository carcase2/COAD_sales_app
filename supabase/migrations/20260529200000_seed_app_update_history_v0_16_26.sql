-- v0.16.26: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.26',
  '개발팀',
  jsonb_build_array(
    '달력 팔로우 상단 날짜 표시 중복 제거',
    '담당자 필터 칩 자동 가로 스크롤'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.26'
);

update public.app_update_policy
set
  latest_version = '0.16.26',
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
  '0.16.26',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
