-- v1.9.1: 자동문의고수 문의종류·담당자 복수선택, 본사일반 주간달력 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수에 문의종류(단순문의·기타문의·타사AS·자사AS)가 들어갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 담당자는 1명 이상 필수이고, 여러 명을 고를 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반이 인트라넷처럼 일~토 주간 달력으로 보이고, 담당자별·도어타입별 색을 바꿀 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수에 문의종류(단순문의·기타문의·타사AS·자사AS)가 들어갑니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 담당자는 1명 이상 필수이고, 여러 명을 고를 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반이 인트라넷처럼 일~토 주간 달력으로 보이고, 담당자별·도어타입별 색을 바꿀 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.1';

update public.app_update_policy
set
  latest_version = '1.9.1',
  updated_at = now()
where is_active = true;
