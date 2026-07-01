-- v0.19.6: 영업 UX·속도 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.6',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '첫 실행 온보딩과 홈·하단 네비 사용 흐름을 다듬었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 탭을 누르면 빠른 동작 시트가 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '로그인·통화 목록·검색·설정 화면을 정리했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 흐름·달력에서 중복 데이터 로드를 줄여 더 빠르게 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급 탭 배지·목록·첨부 이미지 로딩을 최적화했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.6'
);

update public.app_update_policy
set
  latest_version = '0.19.6',
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
  '0.19.6',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
