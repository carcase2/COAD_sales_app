-- v1.0.1: 본사일반·팔로우 UX 개선 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.1',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 주간·월간 달력을 한 화면에서 전환하고 담당자 필터를 공유합니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '월간·주간 달력에 오늘 표시와 월간 통계 펼치기를 정리했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '본사일반 6칸 슬롯 글씨 가독성과 자동 스크롤을 개선했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '팔로우 목록 스와이프를 제거하고 상담 저장 후 목록이 바로 갱신됩니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.1'
);

update public.app_update_policy
set
  latest_version = '1.0.1',
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
  '1.0.1',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
