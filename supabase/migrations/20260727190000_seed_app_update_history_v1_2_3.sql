-- v1.2.3: 견적 입력 공간·홈 바로가기 정리 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.2.3',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적 위저드 하단 버튼 높이를 낮춰 규격 키패드 입력 공간을 확보했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '홈 흐름의 셔터 견적 바로가기 카드를 제거했습니다 (하단 견적 탭 이용)',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.2.3'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적 위저드 하단 버튼 높이를 낮춰 규격 키패드 입력 공간을 확보했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '홈 흐름의 셔터 견적 바로가기 카드를 제거했습니다 (하단 견적 탭 이용)',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.2.3';

update public.app_update_policy
set
  latest_version = '1.2.3',
  updated_at = now()
where is_active = true;
