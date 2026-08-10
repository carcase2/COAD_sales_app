-- v1.3.1: iOS 푸시·상담 입력 UX (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.3.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'iPhone 푸시 알림(접수·발급)을 안정적으로 수신하고 탭 시 상세로 이동합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '여러 기기(아이폰·안드로이드)에 동시에 알림이 가도록 토큰을 기기별로 관리합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상담 입력 시 키보드에 가려지지 않도록 시트를 개선했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.3.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'iPhone 푸시 알림(접수·발급)을 안정적으로 수신하고 탭 시 상세로 이동합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '여러 기기(아이폰·안드로이드)에 동시에 알림이 가도록 토큰을 기기별로 관리합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상담 입력 시 키보드에 가려지지 않도록 시트를 개선했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.3.1';

update public.app_update_policy
set
  latest_version = '1.3.1',
  updated_at = now()
where is_active = true;
