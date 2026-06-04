-- v0.16.37: 수주 상담 상담내용 선택 (제안: 개발팀)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.37',
  '개발팀',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담 결과 「수주」 선택 시 상담내용 없이도 저장 가능',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '수주 등록 화면·저장 버튼 문구 정리',
      'proposer',
      '개발팀'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.37'
);

update public.app_update_policy
set
  latest_version = '0.16.37',
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
  '0.16.37',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
