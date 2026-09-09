-- v1.10.1: 본사일반·대구지사 담당자 색 고정 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.10.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반·대구지사 일정에서 담당자 색이 사람마다 고정됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '달이 바뀌어도 같은 담당자는 같은 색입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.10.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반·대구지사 일정에서 담당자 색이 사람마다 고정됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '달이 바뀌어도 같은 담당자는 같은 색입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.10.1';

update public.app_update_policy
set
  latest_version = '1.10.1',
  updated_at = now()
where is_active = true;
