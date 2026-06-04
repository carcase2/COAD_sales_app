-- v0.16.34 업데이트 내역 제안자: 이상수 팀장

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '흐름·미통화·달력 좌우 스와이프로 섹션 전환 제거(상단 탭만 사용)',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '달력 주간·월간에서 좌우 스와이프로 전주/다음주·전월/다음월 이동',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '달력 오늘 날짜 강조로 한눈에 구분',
      'proposer',
      '이상수 팀장'
    )
  )
where version = '0.16.34';
