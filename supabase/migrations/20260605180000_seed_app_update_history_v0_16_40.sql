-- v0.16.40: 첨부 사진 보기·저장 UX 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.40',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '첨부 사진 전체 화면 확대·더블탭 줌 개선',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '첨부 사진 저장 시 갤러리(사진 앱)에 저장',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.40'
);

update public.app_update_policy
set
  latest_version = '0.16.40',
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
  '0.16.40',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
