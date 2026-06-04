-- v0.16.35: 홈 업데이트 안내 복구 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.35',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 화면 상단에 새 버전 안내 배너 다시 표시',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '로고 옆 업데이트 칩과 함께 최신 버전 확인 가능',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '업데이트 정책 조회 안정화',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.35'
);

update public.app_update_policy
set
  latest_version = '0.16.35',
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
  '0.16.35',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
