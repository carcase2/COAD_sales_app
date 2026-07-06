-- v1.0.0: 정식 출시

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'COAD DOOR 영업 앱 v1.0.0 정식 출시입니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '고객전화 접수·상담·팔로우 업무를 모바일에서 처리할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '발급요청·본사일반 일정 관리와 채널별 푸시 알림을 지원합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '다크 모드·화면 모드 설정으로 사용 환경을 맞출 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.0'
);

update public.app_update_policy
set
  latest_version = '1.0.0',
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
  '1.0.0',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
