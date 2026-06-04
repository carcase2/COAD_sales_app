-- v0.16.38: 홈 업데이트 안내 동기화 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.38',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 「업데이트 있음」·상단 배너가 Play 스토어·업데이트 정책과 같이 표시',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '설정에서 업데이트 확인 후 홈에도 바로 반영',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 실행·백그라운드 복귀 시 업데이트 상태 자동 갱신',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.38'
);

update public.app_update_policy
set
  latest_version = '0.16.38',
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
  '0.16.38',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
