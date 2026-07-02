-- v0.19.9: 현장 안정성·속도 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.9',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '오프라인에서도 상담 내용을 기기에 저장하고, 연결되면 자동으로 서버에 전송합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수·상담·발급·일정 작성 중 뒤로가기 시 저장하지 않고 나갈지 확인합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '목록 「내 건만」 필터와 홈·본사일반 조회 속도를 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '설정에서 새 접수·발급·본사일반 알림을 각각 켜고 끌 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상담 저장 후 상세 화면을 유지하고, 달력 주간 조회 범위를 줄여 더 빠르게 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.9'
);

update public.app_update_policy
set
  latest_version = '0.19.9',
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
  '0.19.9',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
