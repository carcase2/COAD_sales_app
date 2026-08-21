-- v1.5.3 업데이트 내역 제안자: 이상수 팀장

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '셔터 견적 내역에서 스라트·모터·절곡 자재비만 따로 볼 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '절곡 항목을 색으로 구분해 찾기 쉽게 했습니다',
      'proposer',
      '이상수 팀장'
    )
  )
where version = '1.5.3';
