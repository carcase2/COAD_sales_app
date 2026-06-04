-- v0.16.33: 속도·메뉴·미통화 최신 확인 (제안: 개발팀)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.33',
  '개발팀',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '목록·미통화 조회 속도 개선(API 중복·캐시·앱 시작 부하 완화)',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '전체 메뉴 드로어(검색·바로가기) 및 하단 메뉴 탭 추가',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '미통화 탭 시 최신 데이터 확인 후 안내·목록 표시(화면 숫자와 무관)',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '미통화 0건 안내·설정·가독성·업데이트 표시 UX 정리',
      'proposer',
      '개발팀'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.33'
);

update public.app_update_policy
set
  latest_version = '0.16.33',
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
  '0.16.33',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
