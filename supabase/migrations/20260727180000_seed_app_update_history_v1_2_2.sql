-- v1.2.2: 견적 규격 키패드·메뉴·이력 기간 UX (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.2.2',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적 규격을 시스템 키보드 대신 앱 내 숫자 패드로 입력할 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '메뉴 바로가기와 목록이 잘리던 overflow를 수정했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적기 사용 이력에 「전체」 기간을 추가하고, 기간 버튼 글씨 줄바꿈을 고쳤습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.2.2'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적 규격을 시스템 키보드 대신 앱 내 숫자 패드로 입력할 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '메뉴 바로가기와 목록이 잘리던 overflow를 수정했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적기 사용 이력에 「전체」 기간을 추가하고, 기간 버튼 글씨 줄바꿈을 고쳤습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.2.2';

update public.app_update_policy
set
  latest_version = '1.2.2',
  updated_at = now()
where is_active = true;
