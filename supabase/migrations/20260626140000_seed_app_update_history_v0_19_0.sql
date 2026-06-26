-- v0.19.0: 발급·본사일반·통화 UI 개선 (김경덕 이사 제안)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급 탭 첫 화면이 더 빨리 열리도록 경량 건수·지연 로딩을 적용했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급 탭 화면 구성·색상·문구를 정리하고 로딩 중 건수 표시를 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반 화면 제목과 test중 안내가 잘 보이도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화·팔로우 목록 하단 여백을 넉넉히 조정했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.0'
);

update public.app_update_policy
set
  latest_version = '0.19.0',
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
  '0.19.0',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
