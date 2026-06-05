-- v0.16.39: 통화상세 담당자·검색·저장 UX 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.39',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '통화상세 수정에서 지역 변경 시 담당자가 해당 지역 담당자로 자동 반영',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화상세 수정에서 담당자를 regions 기준 리스트(드롭다운)에서 선택',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '통화상세 「전체 정보 수정 저장」 버튼 하단 고정',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '검색 하이라이트 시 일부 글자가 보이지 않던 문제 수정',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '첨부 사진 전체 화면 확대·더블탭 줌 개선',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '첨부 사진 저장 시 갤러리(사진 앱)에 저장',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.39'
);

update public.app_update_policy
set
  latest_version = '0.16.39',
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
  '0.16.39',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
