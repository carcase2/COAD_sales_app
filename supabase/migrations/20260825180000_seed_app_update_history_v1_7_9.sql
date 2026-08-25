-- v1.7.9: 홈 부서 전환·관리자 조회 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.9',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 영업부와 고객지원팀을 좌우로 넘기며 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량·견적기·체크시트 사용 내역은 관리자 그룹만 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.9'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 영업부와 고객지원팀을 좌우로 넘기며 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량·견적기·체크시트 사용 내역은 관리자 그룹만 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.9';

update public.app_update_policy
set
  latest_version = '1.7.9',
  updated_at = now()
where is_active = true;
