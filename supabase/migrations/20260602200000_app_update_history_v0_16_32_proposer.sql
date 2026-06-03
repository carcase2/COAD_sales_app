-- v0.16.32 업데이트 내역 제안자 정정 (1·3: 이상호 팀장, 2: 개발팀)

update public.app_update_history
set
  proposer = '개발팀',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '월간 달력 날짜 탭 시 일자 팔로우 화면에서 좌우 스와이프 이동 지원',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '일자 팔로우 화면에 오늘 버튼 추가(즉시 오늘 날짜 이동)',
      'proposer',
      '개발팀'
    ),
    jsonb_build_object(
      'note',
      '미통화 탭 0건 안내 자동 닫힘 + 흐름 화면 안내 토글 추가',
      'proposer',
      '이상호 팀장'
    )
  )
where version = '0.16.32';
