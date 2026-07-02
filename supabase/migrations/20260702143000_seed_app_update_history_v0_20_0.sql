-- v0.20.0: 사용 편의·알림 채널 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.20.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급 목록을 처음 40건만 빠르게 보여주고, 더 보기로 이어서 불러옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화 목록에서 카드를 스와이프해 전화 걸기·번호 복사가 가능합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화 목록에 새 접수 버튼을 추가해 바로 등록할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '휴대폰 다크 모드 설정에 맞춰 앱 화면도 어둡게 표시됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'Android 알림을 새 접수·발급·본사일반 채널로 나눠 설정에서 따로 관리할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.20.0'
);

update public.app_update_policy
set
  latest_version = '0.20.0',
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
  '0.20.0',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
