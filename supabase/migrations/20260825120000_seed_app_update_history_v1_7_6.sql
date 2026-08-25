-- v1.7.6: 종료 건 팔로우 달력 제외 (제안: 홍창우 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.6',
  '홍창우 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '수주·미수주·단순문의·설계문의는 팔로우 달력에 더 이상 나오지 않습니다',
      'proposer',
      '홍창우 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.6'
);

update public.app_update_history
set
  proposer = '홍창우 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '수주·미수주·단순문의·설계문의는 팔로우 달력에 더 이상 나오지 않습니다',
      'proposer',
      '홍창우 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.6';

update public.app_update_policy
set
  latest_version = '1.7.6',
  updated_at = now()
where is_active = true;
