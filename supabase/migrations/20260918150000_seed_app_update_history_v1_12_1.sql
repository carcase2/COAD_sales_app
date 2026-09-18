-- v1.12.1: 시공완료 안 된 건 상세 닫기 (제안: 이상호 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.12.1',
  '이상호 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '시공완료 안 된 건 상세에 뒤로·닫기 버튼을 넣었습니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.12.1'
);

update public.app_update_history
set
  proposer = '이상호 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '시공완료 안 된 건 상세에 뒤로·닫기 버튼을 넣었습니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.12.1';

update public.app_update_policy
set
  latest_version = '1.12.1',
  updated_at = now()
where is_active = true;
