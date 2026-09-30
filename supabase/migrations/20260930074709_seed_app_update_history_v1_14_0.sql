-- v1.14.0: 앱 사용량 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자만 앱 사용량에서 명함 등록과 표준단가 견적 작성을 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '누가 많이 쓰는지, 최근 사용자, 최근 기록을 기간별로 봅니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '체크시트, 시공 사진 검색, 셔터 견적기 이력도 같은 화면의 탭으로 모았습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자만 앱 사용량에서 명함 등록과 표준단가 견적 작성을 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '누가 많이 쓰는지, 최근 사용자, 최근 기록을 기간별로 봅니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '체크시트, 시공 사진 검색, 셔터 견적기 이력도 같은 화면의 탭으로 모았습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.0';

update public.app_update_policy
set
  latest_version = '1.14.0',
  updated_at = now()
where is_active = true;
