-- v1.12.0: 시공완료 안 된 건에서 세금계산서 바로 요청 (제안: 이상호 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.12.0',
  '이상호 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 오늘 이전·시공완료 안 된 건수를 보고 담당자별로 목록을 엽니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '담당자 필터와 색으로 나·전체·사람별 현장을 나눕니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '달력·리스트에서 계약완료보고서·체크시트를 보고 크게 넘길 수 있습니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '상세에서 현장·금액으로 세금계산서를 바로 요청하고, 이미 요청한 건은 구분됩니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.12.0'
);

update public.app_update_history
set
  proposer = '이상호 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 오늘 이전·시공완료 안 된 건수를 보고 담당자별로 목록을 엽니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '담당자 필터와 색으로 나·전체·사람별 현장을 나눕니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '달력·리스트에서 계약완료보고서·체크시트를 보고 크게 넘길 수 있습니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '상세에서 현장·금액으로 세금계산서를 바로 요청하고, 이미 요청한 건은 구분됩니다',
      'proposer',
      '이상호 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.12.0';

update public.app_update_policy
set
  latest_version = '1.12.0',
  updated_at = now()
where is_active = true;
