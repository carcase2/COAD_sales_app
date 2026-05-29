-- v0.16.25: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.25',
  '개발팀',
  jsonb_build_array(
    '달력 날짜 팔로우: 담당자 필터 스와이프 시 유지',
    '해당 일에 건이 없어도 선택 담당자 기준 표시'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.25'
);

update public.app_update_policy
set
  latest_version = '0.16.25',
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
  '0.16.25',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
