-- v0.20.2: 본사일반 속도·편의·가독성 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.20.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 일정 저장·수정 후 화면 반영 속도를 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반 검색 결과를 선택하면 화면에 검색 상태가 유지됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반 슬롯 카드 정보를 2줄로 정리해 가독성을 높였습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.20.2'
);

update public.app_update_policy
set
  latest_version = '0.20.2',
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
  '0.20.2',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
