-- v1.1.6 업데이트 내역 제안자: 이상수 팀장

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '홈 흐름에 금일 업데이트 카드를 추가했습니다 (updated_at 기준 전체)',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '홈 통계 카드 레이아웃을 라벨+숫자 형태로 보기 좋게 정리했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      'iOS에서 Firebase 미초기화 시 로그인이 막히던 문제를 수정했습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      'iOS 최소 지원 버전을 15.0으로 올렸습니다',
      'proposer',
      '이상수 팀장'
    )
  )
where version = '1.1.6';
