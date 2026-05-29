-- v0.16.23: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.23',
  '개발팀',
  jsonb_build_array(
    '흐름 탭 통계 로드 실패 시 짧은 네트워크 안내',
    '오류 화면 overflow(화면 깨짐) 수정'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.23'
);

update public.app_update_policy
set
  latest_version = '0.16.23',
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
  '0.16.23',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
