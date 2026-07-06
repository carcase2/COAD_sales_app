-- v1.0.2: 본사일반 8칸·검색 뒤로가기 개선 (제안: 이상수 팀장, 이상호 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.2',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 일정 칸을 하루 8칸으로 늘렸습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '본사일반 검색에서 상세 보기 후 뒤로가기 시 검색 목록으로 돌아갑니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '홈 통합 검색에서 상세 보기 후 뒤로가기 시 검색 목록으로 돌아갑니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.2'
);

update public.app_update_policy
set
  latest_version = '1.0.2',
  updated_at = now()
where is_active = true;

insert into public.app_update_policy (
  min_version,
  latest_version,
  store_url,
  force_update,
  is_active,
  updated_at
)
select
  '0.16.0',
  '1.0.2',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
