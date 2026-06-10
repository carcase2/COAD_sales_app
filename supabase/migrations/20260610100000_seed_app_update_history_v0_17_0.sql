-- v0.17.0: 발급요청·처리할 미통화·통화 표시 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.17.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급대기: 내 요청 우선·배지·발행요청 폼 UX 개선',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '처리할 미통화: 최근 60일 이월 건 포함 조회',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화 목록·검색·상세에 문의 경로 표시',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.17.0'
);

update public.app_update_policy
set
  latest_version = '0.17.0',
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
  '0.17.0',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
