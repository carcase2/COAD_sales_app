-- v1.4.0: 체크시트 아카이브 검색 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.4.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'MES 아카이브 체크시트(TP1)를 앱에서 검색·조회할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '연·월 필터와 키워드 검색으로 원하는 체크시트를 빠르게 찾습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '관리자는 체크시트 사용 내역·순위를 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.4.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'MES 아카이브 체크시트(TP1)를 앱에서 검색·조회할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '연·월 필터와 키워드 검색으로 원하는 체크시트를 빠르게 찾습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '관리자는 체크시트 사용 내역·순위를 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.4.0';

update public.app_update_policy
set
  latest_version = '1.4.0',
  updated_at = now()
where is_active = true;
