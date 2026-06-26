-- v0.19.2: 홈 미통화 탭 제거·흐름 통합 (김경덕 이사 제안)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 화면을 흐름·달력 2탭으로 단순화하고 미통화 탭을 제거했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '처리할 미통화 건수 배지를 흐름 탭에 표시합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '메뉴 「처리할 미통화」에서 본인 미통화 목록으로 바로 이동합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '흐름 탭의 처리할 미통화·전일 미통화 배너와 카드로 미통화를 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.2'
);

update public.app_update_policy
set
  latest_version = '0.19.2',
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
  '0.19.2',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
