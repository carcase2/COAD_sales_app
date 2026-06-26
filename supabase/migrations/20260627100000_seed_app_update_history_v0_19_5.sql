-- v0.19.5: 본사일반 FCM 알림 제목·본문 개선 (김경덕 이사 제안)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.19.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 일정 등록·수정·삭제 시 본사영업·관리자에게 FCM 푸시 알림이 갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림 제목에 [본사일반]·현장명이 표시됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림 본문에 현장·입력자·이달 남은 빈 칸·가장 빠른 빈 칸 날짜가 표시됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '알림을 탭하면 본사일반 일정 화면으로 이동합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '일정 저장 후 FCM 전송 안정성을 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반 일정·FCM 알림은 본사(본사영업·관리자)에만 해당하며, 대구지사 등 다른 조직에는 적용되지 않습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.19.5'
);

update public.app_update_policy
set
  latest_version = '0.19.5',
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
  '0.19.5',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
