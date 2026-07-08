-- v1.0.5: 앱 사용량 — 실제 앱 사용자만 표시

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '앱 사용량 화면에 실제로 앱을 사용한 직원만 표시되도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '인트라넷 전체 사용자가 목록에 나오던 문제를 제거했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.5'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '앱 사용량 화면에 실제로 앱을 사용한 직원만 표시되도록 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '인트라넷 전체 사용자가 목록에 나오던 문제를 제거했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.0.5';

update public.app_update_policy
set
  latest_version = '1.0.5',
  updated_at = now()
where is_active = true;
