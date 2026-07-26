-- v1.2.0: 현장 UX·견적기·체감 속도 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.2.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈·목록·상세에 상태 배너와 하단 액션 독을 적용해 한 손 조작을 쉽게 했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '하단 네비 가운데 「접수」를 큰 버튼으로 바꿔 바로 등록할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '셔터 견적 계산·로그 화면과 견적 흐름을 보강했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '탭 전환·스크롤·이미지 캐시를 다듬어 체감 속도를 개선했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.2.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈·목록·상세에 상태 배너와 하단 액션 독을 적용해 한 손 조작을 쉽게 했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '하단 네비 가운데 「접수」를 큰 버튼으로 바꿔 바로 등록할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '셔터 견적 계산·로그 화면과 견적 흐름을 보강했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '탭 전환·스크롤·이미지 캐시를 다듬어 체감 속도를 개선했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.2.0';

update public.app_update_policy
set
  latest_version = '1.2.0',
  updated_at = now()
where is_active = true;
