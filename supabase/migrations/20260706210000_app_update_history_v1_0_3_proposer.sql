-- v1.0.3 업데이트 내역 제안자 정정: 이상호 팀장

update public.app_update_history
set
  proposer = '이상호 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '본사일반 월간 달력 날짜 칸에 8칸이 모두 보이도록 표시를 개선했습니다',
      'proposer',
      '이상호 팀장'
    ),
    jsonb_build_object(
      'note',
      '빈 칸도 포함해 8줄로 균등 표시되어 일정 칸 수를 한눈에 확인할 수 있습니다',
      'proposer',
      '이상호 팀장'
    )
  )
where version = '1.0.3';
