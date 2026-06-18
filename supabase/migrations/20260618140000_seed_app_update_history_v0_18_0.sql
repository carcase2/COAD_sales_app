-- v0.18.0: 발급요청 UX 정리 + 이행증권 취소 수정

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.18.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청하기·발급대기 통합 — 세금계산서/이행증권 한 화면에서 확인',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '이행증권 발급요청 취소 시 상태가 반영되지 않던 문제 수정',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급요청 취소 다이얼로그 오류·Bad Request 메시지 개선',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '이행증권 상세·첨부 미리보기 및 보증기간 표시 웹과 동일하게 정리',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.18.0'
);

update public.app_update_policy
set
  latest_version = '0.18.0',
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
  '0.18.0',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
