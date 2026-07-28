-- v1.3.0: 대구지사 일정 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.3.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '대구지사장·관리자용 「대구지사」 일정 탭을 추가했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반과 동일한 일정 UI로 대구 전용 테이블·알림을 분리했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '푸시 알림으로 대구지사 일정 등록·변경을 받을 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.3.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '대구지사장·관리자용 「대구지사」 일정 탭을 추가했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반과 동일한 일정 UI로 대구 전용 테이블·알림을 분리했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '푸시 알림으로 대구지사 일정 등록·변경을 받을 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.3.0';

update public.app_update_policy
set
  latest_version = '1.3.0',
  updated_at = now()
where is_active = true;
