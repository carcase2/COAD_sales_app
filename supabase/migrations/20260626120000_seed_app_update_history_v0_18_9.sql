-- v0.18.9: 발급대기 건수 표시 수정 (김경덕 이사 요청)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.9',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발행 요청 후 발급대기 건수가 목록과 같이 바로 표시되도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급대기 숫자와 실제 대기 목록 건수가 맞지 않던 문제를 해결했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.9'
);

update public.app_update_policy
set
  latest_version = '0.18.9',
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
  '0.18.9',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
