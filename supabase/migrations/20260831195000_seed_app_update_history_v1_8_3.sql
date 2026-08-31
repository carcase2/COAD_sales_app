-- v1.8.3: 자동문의고수 팔로업중 = 종료 전 전체 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.8.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '팔로업중은 종료되기 전 접수를 모두 보여 줍니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '기존진행중은 1차 상담 이후 미종료 건입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.8.3'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '팔로업중은 종료되기 전 접수를 모두 보여 줍니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '기존진행중은 1차 상담 이후 미종료 건입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.8.3';

update public.app_update_policy
set
  latest_version = '1.8.3',
  updated_at = now()
where is_active = true;
