-- v0.19.3: 통화 목록 플로팅 메뉴 제거 (김경덕 이사 제안)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '통화 목록 화면(오늘 접수·처리할 미통화 등) 우하단 플로팅 메뉴 버튼을 제거했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '목록 상단 홈·검색 버튼과 하단 탭·메뉴로 동일 기능에 접근할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.3'
);

update public.app_update_policy
set
  latest_version = '0.19.3',
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
  '0.19.3',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
