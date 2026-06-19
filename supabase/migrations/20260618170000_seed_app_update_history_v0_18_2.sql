-- v0.18.2: 접수 알림·접수 일시 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '신규 접수 푸시를 담당자·관리자만 받도록 조정 (담당자 미지정 시 전체)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '고객전화 접수 일시를 한국 시간(KST)으로 통일 표시 (목록·상세·미통화)',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.2'
);

update public.app_update_policy
set
  latest_version = '0.18.2',
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
  '0.18.2',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
