-- v0.16.32: 달력 팔로우 이동·미통화 안내 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.32',
  '개발팀',
  jsonb_build_array(
    '월간 달력 날짜 탭 시 일자 팔로우 화면에서 좌우 스와이프 이동 지원',
    '일자 팔로우 화면에 오늘 버튼 추가(즉시 오늘 날짜 이동)',
    '미통화 탭 0건 안내 자동 닫힘 + 흐름 화면 안내 토글 추가'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.32'
);

update public.app_update_policy
set
  latest_version = '0.16.32',
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
  '0.16.32',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
