-- v1.1.3: 홈 흐름 카드 새로고침 수정 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.3',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 화면에서 아래로 당겨 새로고침해도 접수·미통화·팔로우 카드가 0으로 남던 문제를 수정했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '금일 접수 목록에는 숫자가 있는데 카드만 0이던 경우를 바로잡았습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '새로고침 시 카드 숫자가 서버 기준으로 다시 불러와지도록 개선했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.3'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 화면에서 아래로 당겨 새로고침해도 접수·미통화·팔로우 카드가 0으로 남던 문제를 수정했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '금일 접수 목록에는 숫자가 있는데 카드만 0이던 경우를 바로잡았습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '새로고침 시 카드 숫자가 서버 기준으로 다시 불러와지도록 개선했습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.3';

update public.app_update_policy
set
  latest_version = '1.1.3',
  updated_at = now()
where is_active = true;
