-- v1.8.0: 자동문의고수 알림 보완 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.8.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수 시 관리자와 해당 부서에 알림이 더 안정적으로 갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈·접수·팔로업·달력 등 자동문의고수 기능을 계속 사용할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.8.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수 시 관리자와 해당 부서에 알림이 더 안정적으로 갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈·접수·팔로업·달력 등 자동문의고수 기능을 계속 사용할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.8.0';

update public.app_update_policy
set
  latest_version = '1.8.0',
  updated_at = now()
where is_active = true;
