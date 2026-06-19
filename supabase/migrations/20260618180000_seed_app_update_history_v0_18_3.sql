-- v0.18.3: 발급 UX 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급 허브·탭 배지를 내 발급대기 건수 기준으로 통일',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '금일 발급완료를 발행일 기준으로 표시하고 상세에서 발급 문서 확인',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급 목록 오류 시 다시 시도 버튼 추가',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.3'
);

update public.app_update_policy
set
  latest_version = '0.18.3',
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
  '0.18.3',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
