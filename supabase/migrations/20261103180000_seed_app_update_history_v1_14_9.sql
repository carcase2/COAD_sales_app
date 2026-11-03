-- v1.14.9: 스크린방화 0원 수정·셔터 견적 규격 입력 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.9',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '스크린방화 셔터 견적이 0원으로 나오던 문제를 고쳤습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '셔터 견적 규격 버튼을 자주 쓰는 크기로 바꾸고, 최근 규격이 앞에 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '「3000x2500」처럼 복사한 규격을 붙여넣기 한 번으로 넣습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.9'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '스크린방화 셔터 견적이 0원으로 나오던 문제를 고쳤습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '셔터 견적 규격 버튼을 자주 쓰는 크기로 바꾸고, 최근 규격이 앞에 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '「3000x2500」처럼 복사한 규격을 붙여넣기 한 번으로 넣습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.9';

update public.app_update_policy
set
  latest_version = '1.14.9',
  updated_at = now()
where is_active = true;
