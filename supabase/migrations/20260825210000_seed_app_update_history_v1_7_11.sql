-- v1.7.11: 표준단가 전원 조회 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.11',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가를 로그인한 사람이면 모두 조회할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가 수정은 인트라넷에서만 하고, 앱에서는 조회만 됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.11'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가를 로그인한 사람이면 모두 조회할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가 수정은 인트라넷에서만 하고, 앱에서는 조회만 됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.11';

update public.app_update_policy
set
  latest_version = '1.7.11',
  updated_at = now()
where is_active = true;
