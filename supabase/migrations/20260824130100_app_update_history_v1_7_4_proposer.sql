-- v1.7.4 업데이트 내역 제안자: 홍창우 이사

update public.app_update_history
set
  proposer = '홍창우 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 영업부·고객지원팀 카드 글자와 터치 영역을 키웠습니다',
      'proposer',
      '홍창우 이사'
    ),
    jsonb_build_object(
      'note',
      '홈에서 영업부와 고객지원팀 현황을 모두 볼 수 있습니다',
      'proposer',
      '홍창우 이사'
    )
  )
where version = '1.7.4';
