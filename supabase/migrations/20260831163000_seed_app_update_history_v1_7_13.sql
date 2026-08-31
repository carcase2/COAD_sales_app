-- v1.7.13: 자동문의고수 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.13',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 자동문의고수 부서를 볼 수 있고, 하단 접수는 보고 있는 부서 탭으로 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 접수·팔로업·달력을 앱에서 처리할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 접수가 등록되면 관리자와 해당 부서에 알림이 갑니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.13'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈에서 자동문의고수 부서를 볼 수 있고, 하단 접수는 보고 있는 부서 탭으로 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 접수·팔로업·달력을 앱에서 처리할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 접수가 등록되면 관리자와 해당 부서에 알림이 갑니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.13';

update public.app_update_policy
set
  latest_version = '1.7.13',
  updated_at = now()
where is_active = true;
