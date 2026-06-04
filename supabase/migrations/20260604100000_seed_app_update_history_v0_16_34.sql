-- v0.16.34: 홈 섹션·달력 스와이프·오늘 표시 개선 (제안: 개발팀)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.34',
  '개발팀',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '흐름·미통화·달력 좌우 스와이프로 섹션 전환 제거(상단 탭만 사용)',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '달력 주간·월간에서 좌우 스와이프로 전주/다음주·전월/다음월 이동',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '달력 오늘 날짜 강조로 한눈에 구분',
      'proposer',
      '개발팀'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.34'
);

update public.app_update_policy
set
  latest_version = '0.16.34',
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
  '0.16.34',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
