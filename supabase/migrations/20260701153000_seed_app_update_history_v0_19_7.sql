-- v0.19.7: 목록·메뉴·품질지표 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.7',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '오늘 접수·오늘 팔로우 목록의 담당자 필터 글씨가 잘리지 않도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '메뉴에서 설정·로그아웃이 중복 표시되던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 품질 지표에 팔로우 예정·완료·남음 건수를 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.7'
);

update public.app_update_policy
set
  latest_version = '0.19.7',
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
  '0.19.7',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
