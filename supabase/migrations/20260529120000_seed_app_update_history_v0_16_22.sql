-- v0.16.22: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.22',
  '개발팀',
  jsonb_build_array(
    '발급요청: 발급대기·부분발급·전체·발급완료 전용 화면',
    '세금계산서 발급·발급요청·잔금 발급 정비',
    '발급완료 발행일·MES 필터',
    '미수주 상담 시 사유만 입력해도 저장 (상담내용 선택)'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.22'
);

update public.app_update_policy
set
  latest_version = '0.16.22',
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
  '0.16.22',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
