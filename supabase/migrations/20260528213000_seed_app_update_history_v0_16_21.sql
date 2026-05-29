-- v0.16.21: 설정 > 업데이트 내역 표시 + 업데이트 정책 latest_version 반영

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '0.16.21',
  '개발팀',
  jsonb_build_array(
    '발급요청 탭(세금계산서·이행증권) 다시 사용 가능',
    '발급요청 목록 DB 컬럼 불일치 오류 수정',
    '홈 흐름·미통화·달력 당겨서 새로고침 복구',
    '상단 COAD 로고 탭 시 홈 흐름(금일)으로 바로 이동'
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '0.16.21'
);

-- 활성 업데이트 정책이 있으면 latest_version만 올림
update public.app_update_policy
set
  latest_version = '0.16.21',
  updated_at = now()
where is_active = true;

-- 활성 정책이 없을 때만 기본 행 생성
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
  '0.16.21',
  'https://play.google.com/store/apps/details?id=com.coad.customer_calls',
  false,
  true,
  now()
where not exists (
  select 1
  from public.app_update_policy
  where is_active = true
);
