-- v1.14.7: 일정 탭 통합·홈 상단 접힘·첫 화면 속도 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.7',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '하단 본사일반·대구지사 탭을 「일정」 하나로 합쳤습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 숫자가 앱을 켜자마자 뜹니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈을 아래로 내리면 위쪽 조작 줄이 접혀 숫자 카드가 넓게 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.7'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '하단 본사일반·대구지사 탭을 「일정」 하나로 합쳤습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 숫자가 앱을 켜자마자 뜹니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈을 아래로 내리면 위쪽 조작 줄이 접혀 숫자 카드가 넓게 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.7';

update public.app_update_policy
set
  latest_version = '1.14.7',
  updated_at = now()
where is_active = true;
