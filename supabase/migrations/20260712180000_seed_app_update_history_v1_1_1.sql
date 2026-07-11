-- v1.1.1: 본사일반 월간 UX 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 월간 달력에도 오늘·빈 칸 추가 버튼을 넣었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '월간 빈 칸 + 표시를 더 잘 보이게 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '오늘 버튼으로 다른 달에서도 현재 월·오늘로 바로 이동합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 월간 달력에도 오늘·빈 칸 추가 버튼을 넣었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '월간 빈 칸 + 표시를 더 잘 보이게 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '오늘 버튼으로 다른 달에서도 현재 월·오늘로 바로 이동합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.1';

update public.app_update_policy
set
  latest_version = '1.1.1',
  updated_at = now()
where is_active = true;
