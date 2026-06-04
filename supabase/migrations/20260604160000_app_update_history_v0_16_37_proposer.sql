-- v0.16.37 업데이트 내역 제안자: 김경덕 이사

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '상담 결과 「수주」 선택 시 상담내용 없이도 저장 가능',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '수주 등록 화면·저장 버튼 문구 정리',
      'proposer',
      '김경덕 이사'
    )
  )
where version = '0.16.37';
