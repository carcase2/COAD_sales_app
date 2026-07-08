-- v1.0.4: 관리자 앱 사용량 통계

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.0.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자가 직원별 앱 사용량(실행 횟수·사용일·주로 쓴 탭)을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '활성 사용자 전원이 목록에 표시되며, 설정·메뉴 「사용량」에서 최근 7·14·30일 통계를 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.0.4'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자가 직원별 앱 사용량(실행 횟수·사용일·주로 쓴 탭)을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '활성 사용자 전원이 목록에 표시되며, 설정·메뉴 「사용량」에서 최근 7·14·30일 통계를 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.0.4';

update public.app_update_policy
set
  latest_version = '1.0.4',
  updated_at = now()
where is_active = true;
