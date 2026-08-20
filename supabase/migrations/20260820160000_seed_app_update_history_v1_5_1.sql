-- v1.5.1: 명함 테두리 자동 맞춤 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.5.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 사진에서 세로·가로 테두리를 찾아 자르기 영역을 맞춥니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '테두리를 못 찾으면 직접 조정할 수 있고, 다시 찾기도 가능합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상세에서 명함 사진을 눌러 확대·축소할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.5.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 사진에서 세로·가로 테두리를 찾아 자르기 영역을 맞춥니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '테두리를 못 찾으면 직접 조정할 수 있고, 다시 찾기도 가능합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상세에서 명함 사진을 눌러 확대·축소할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.5.1';

update public.app_update_policy
set
  latest_version = '1.5.1',
  updated_at = now()
where is_active = true;
