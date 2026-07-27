-- v1.2.1: 접수 상세 상담 버튼·사용량 라벨 개선 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.2.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 상세 하단 「N차 상담내용」 버튼 글씨가 잘리던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량 화면에서 quoter를 「견적」「견적 로그」로 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.2.1'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 상세 하단 「N차 상담내용」 버튼 글씨가 잘리던 문제를 수정했습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 사용량 화면에서 quoter를 「견적」「견적 로그」로 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.2.1';

update public.app_update_policy
set
  latest_version = '1.2.1',
  updated_at = now()
where is_active = true;
