-- v1.1.2: 접수 경과 시간(KST) 수정 (제안: 이상호 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.2',
  '이상호 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객전화 접수 직후 「접수 후 9시간 경과」로 보이던 문제를 수정했습니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '접수 시각을 한국 시간(KST)으로 저장·표시하도록 맞췄습니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.2'
);

update public.app_update_history
set
  proposer = '이상호 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객전화 접수 직후 「접수 후 9시간 경과」로 보이던 문제를 수정했습니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '접수 시각을 한국 시간(KST)으로 저장·표시하도록 맞췄습니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.2';

update public.app_update_policy
set
  latest_version = '1.1.2',
  updated_at = now()
where is_active = true;
