-- v0.17.5: 발급 알림·상세 이동 안정화 + 흐름 전일 미통화

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.17.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급 완료 푸시 알림 및 알림 탭 시 세부내용 이동',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림 탭 후 상세 반복 열림·발급대기 로딩 멈춤 수정',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '흐름 탭 전일 미통화 카드 — 어제 접수 미통화 확인·목록 이동',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.17.5'
);

update public.app_update_policy
set
  latest_version = '0.17.5',
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
  '0.17.5',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
