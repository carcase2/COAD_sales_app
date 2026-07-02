-- v0.20.1: 화면 모드 설정

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.20.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '설정에서 화면 모드를 밝게·어둡게·시스템 설정 중에서 고를 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '기본 화면은 밝게 표시되며, 휴대폰 다크 모드와 무관하게 시작합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.20.1'
);

update public.app_update_policy
set
  latest_version = '0.20.1',
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
  '0.20.1',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
