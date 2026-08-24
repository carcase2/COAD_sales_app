-- v1.7.5: 홈 전일 대비 문구 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 영업부 전일 대비 접수에서 현재·이전 건수가 잘리지 않게 두 줄로 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.5'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 영업부 전일 대비 접수에서 현재·이전 건수가 잘리지 않게 두 줄로 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.5';

update public.app_update_policy
set
  latest_version = '1.7.5',
  updated_at = now()
where is_active = true;
