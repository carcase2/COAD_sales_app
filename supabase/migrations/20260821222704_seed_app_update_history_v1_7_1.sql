-- v1.7.1: 내풍압 자재비 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.1',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '내풍압 셔터는 자재비에 윈드락·프레임까지 포함해 보여 줍니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적 상세에서 롤파이프와 브라켓 종류를 한 줄씩 읽기 쉽게 했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.1'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '내풍압 셔터는 자재비에 윈드락·프레임까지 포함해 보여 줍니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적 상세에서 롤파이프와 브라켓 종류를 한 줄씩 읽기 쉽게 했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.1';

update public.app_update_policy
set
  latest_version = '1.7.1',
  updated_at = now()
where is_active = true;
