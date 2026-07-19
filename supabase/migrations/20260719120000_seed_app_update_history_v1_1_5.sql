-- v1.1.5: 처리할 미통화 불러오기 재시도 수정 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 흐름의 처리할 미통화가 불러오기 실패 후 탭해도 같은 오류가 반복되던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '재시도 시 미통화 목록을 서버에서 다시 조회하도록 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '임시 담당자 조회 실패만으로 미통화 배너가 막히지 않도록 완화했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.5'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 흐름의 처리할 미통화가 불러오기 실패 후 탭해도 같은 오류가 반복되던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '재시도 시 미통화 목록을 서버에서 다시 조회하도록 개선했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '임시 담당자 조회 실패만으로 미통화 배너가 막히지 않도록 완화했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.5';

update public.app_update_policy
set
  latest_version = '1.1.5',
  updated_at = now()
where is_active = true;
