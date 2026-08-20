-- v1.5.2: 명함 사진 확대 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.5.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 상세에서 사진을 눌러 확대 보기가 더 잘 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '확대 화면에서 두 손가락으로 확대·축소할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.5.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 상세에서 사진을 눌러 확대 보기가 더 잘 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '확대 화면에서 두 손가락으로 확대·축소할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.5.2';

update public.app_update_policy
set
  latest_version = '1.5.2',
  updated_at = now()
where is_active = true;
