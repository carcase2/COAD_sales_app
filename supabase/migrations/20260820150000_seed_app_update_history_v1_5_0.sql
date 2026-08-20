-- v1.5.0: 명함 수첩·표준단가 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.5.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함을 촬영해 등록하고, 검색·메모·블랙리스트를 쓸 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가를 조회하고 조정할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.5.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함을 촬영해 등록하고, 검색·메모·블랙리스트를 쓸 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가를 조회하고 조정할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.5.0';

update public.app_update_policy
set
  latest_version = '1.5.0',
  updated_at = now()
where is_active = true;
