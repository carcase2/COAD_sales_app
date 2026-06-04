-- v0.16.36: 달력 스와이프·홈 업데이트 안내 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.36',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '달력 좌우 스와이프 시 달력만 전주/다음주·전월/다음월 이동(상단 메뉴 유지)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '달력 주·월 전환 애니메이션·로딩 표시 개선',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 상단 인사 앞 「업데이트 있음」 표시·탭하여 업데이트',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.36'
);

update public.app_update_policy
set
  latest_version = '0.16.36',
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
  '0.16.36',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
