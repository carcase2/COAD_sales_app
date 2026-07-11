-- v1.1.0: UX·성능 개선

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 목록 로딩을 빠르게 하고 다크 테마·홈 화면을 다듬었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반을 하단 탭으로 옮겨 메인 화면으로 바로 돌아올 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세 제목 잘림·삭제 후 멈춤, 발급 허브 카드 넘침을 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량에 금일·전일 기간을 추가하고 조회 오류를 고쳤습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 목록 로딩을 빠르게 하고 다크 테마·홈 화면을 다듬었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '본사일반을 하단 탭으로 옮겨 메인 화면으로 바로 돌아올 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세 제목 잘림·삭제 후 멈춤, 발급 허브 카드 넘침을 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량에 금일·전일 기간을 추가하고 조회 오류를 고쳤습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.0';

update public.app_update_policy
set
  latest_version = '1.1.0',
  updated_at = now()
where is_active = true;
