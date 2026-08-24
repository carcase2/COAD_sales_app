-- v1.7.4: 홈 카드 확대 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 영업부·고객지원팀 카드 글자와 터치 영역을 키웠습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈에서 영업부와 고객지원팀 현황을 모두 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.4'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 영업부·고객지원팀 카드 글자와 터치 영역을 키웠습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈에서 영업부와 고객지원팀 현황을 모두 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.4';

update public.app_update_policy
set
  latest_version = '1.7.4',
  updated_at = now()
where is_active = true;
