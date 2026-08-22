-- v1.7.3 업데이트 내역 제안자: 이상수 팀장

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '메뉴에서 메일 발송을 열고 자료실 파일을 골라 보낼 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '받는 사람은 명함에서 고르고, 보내는 사람은 로그인 계정으로 고정됩니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '보낸 메일에서 다시 보낼 수 있습니다',
      'proposer',
      '이상수 팀장'
    )
  )
where version = '1.7.3';
