-- v1.11.1: 본사 영업 본사일반 복구 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.11.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사 영업에게 본사일반 일정이 다시 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.11.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사 영업에게 본사일반 일정이 다시 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.11.1';

update public.app_update_policy
set
  latest_version = '1.11.1',
  updated_at = now()
where is_active = true;
