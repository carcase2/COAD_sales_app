-- v1.14.1: 견적 탭 사용량 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '앱 사용량에서 견적 메뉴를 셔터 견적기·표준단가·견적서로 나눠 봅니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '견적 메뉴에서 탭을 열거나 바꿀 때마다 사용 기록이 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '앱 사용량에서 견적 메뉴를 셔터 견적기·표준단가·견적서로 나눠 봅니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '견적 메뉴에서 탭을 열거나 바꿀 때마다 사용 기록이 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.1';

update public.app_update_policy
set
  latest_version = '1.14.1',
  updated_at = now()
where is_active = true;
