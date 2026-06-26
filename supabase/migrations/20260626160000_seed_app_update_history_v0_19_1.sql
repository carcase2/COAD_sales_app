-- v0.19.1: 오늘 팔로우·달력 UX 개선 (김경덕 이사 제안)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '오늘 팔로우 목록에서 날짜를 스와이프로 넘길 수 있도록 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '달력에 오늘 팔로우 바로가기 버튼을 추가하고 담당자 선택을 편하게 했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '팔로우 목록에서 고객명·연락처로 검색할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '달력에서 마지막으로 보던 주·월이 유지되도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.1'
);

update public.app_update_policy
set
  latest_version = '0.19.1',
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
  '0.19.1',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
