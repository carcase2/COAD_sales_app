-- v0.16.38 업데이트 내역 제안자: 김경덕 이사

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 「업데이트 있음」·상단 배너가 Play 스토어·업데이트 정책과 같이 표시',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '설정에서 업데이트 확인 후 홈에도 바로 반영',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '앱 실행·백그라운드 복귀 시 업데이트 상태 자동 갱신',
      'proposer',
      '김경덕 이사'
    )
  )
where version = '0.16.38';
