-- v1.5.3: 셔터 자재비 보기 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.5.3',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '셔터 견적 내역에서 스라트·모터·절곡 자재비만 따로 볼 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '절곡 항목을 색으로 구분해 찾기 쉽게 했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.5.3'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '셔터 견적 내역에서 스라트·모터·절곡 자재비만 따로 볼 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '절곡 항목을 색으로 구분해 찾기 쉽게 했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.5.3';

update public.app_update_policy
set
  latest_version = '1.5.3',
  updated_at = now()
where is_active = true;
