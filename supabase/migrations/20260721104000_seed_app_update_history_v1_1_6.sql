-- v1.1.6: 홈 금일 업데이트·iOS 로그인 안정화 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.6',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 흐름에 금일 업데이트 카드를 추가했습니다 (updated_at 기준 전체)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 통계 카드 레이아웃을 라벨+숫자 형태로 보기 좋게 정리했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'iOS에서 Firebase 미초기화 시 로그인이 막히던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'iOS 최소 지원 버전을 15.0으로 올렸습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.6'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 흐름에 금일 업데이트 카드를 추가했습니다 (updated_at 기준 전체)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 통계 카드 레이아웃을 라벨+숫자 형태로 보기 좋게 정리했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'iOS에서 Firebase 미초기화 시 로그인이 막히던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'iOS 최소 지원 버전을 15.0으로 올렸습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.6';

update public.app_update_policy
set
  latest_version = '1.1.6',
  updated_at = now()
where is_active = true;
