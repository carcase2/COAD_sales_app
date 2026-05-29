-- v0.16.24: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.24',
  '개발팀',
  jsonb_build_array(
    '미수주 시 상담내용 없이 사유만 입력',
    '달력 날짜 팔로우 전·후일 스와이프'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.24'
);

update public.app_update_policy
set
  latest_version = '0.16.24',
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
  '0.16.24',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
