-- v1.1.7: Play 반영 전 업데이트 안내 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.7',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'Play 스토어에 새 빌드가 올라오기 전에 업데이트 안내가 뜨던 문제를 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '선택 업데이트는 Play에 실제 업데이트가 있을 때만 표시합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'Play 미반영 시에는 곧 반영된다는 안내만 보여 불필요한 재시도를 줄였습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.7'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'Play 스토어에 새 빌드가 올라오기 전에 업데이트 안내가 뜨던 문제를 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '선택 업데이트는 Play에 실제 업데이트가 있을 때만 표시합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'Play 미반영 시에는 곧 반영된다는 안내만 보여 불필요한 재시도를 줄였습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.7';

update public.app_update_policy
set
  latest_version = '1.1.7',
  updated_at = now()
where is_active = true;
