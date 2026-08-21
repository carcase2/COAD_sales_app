-- v1.7.2: 전일 미처리 안내 (제안: 남현우 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.2',
  '남현우 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원 홈에서 전일 미처리 건수를 바로 확인하고 목록으로 갈 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '전일 미통화는 영업 미통화만 보여 혼동을 줄였습니다',
      'proposer',
      '남현우 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.2'
);

update public.app_update_history
set
  proposer = '남현우 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원 홈에서 전일 미처리 건수를 바로 확인하고 목록으로 갈 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '전일 미통화는 영업 미통화만 보여 혼동을 줄였습니다',
      'proposer',
      '남현우 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.2';

update public.app_update_policy
set
  latest_version = '1.7.2',
  updated_at = now()
where is_active = true;
