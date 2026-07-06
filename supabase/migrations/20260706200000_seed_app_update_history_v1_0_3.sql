-- v1.0.3: 본사일반 월간 달력 8칸 표시 보강

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.3',
  '이상호 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 월간 달력 날짜 칸에 8칸이 모두 보이도록 표시를 개선했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '빈 칸도 포함해 8줄로 균등 표시되어 일정 칸 수를 한눈에 확인할 수 있습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.3'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 월간 달력 날짜 칸에 8칸이 모두 보이도록 표시를 개선했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '빈 칸도 포함해 8줄로 균등 표시되어 일정 칸 수를 한눈에 확인할 수 있습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.0.3';

update public.app_update_policy
set
  latest_version = '1.0.3',
  updated_at = now()
where is_active = true;
