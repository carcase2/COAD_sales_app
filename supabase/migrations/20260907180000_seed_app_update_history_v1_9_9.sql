-- v1.9.9: A/S 견적·방문 팀 구분·고객 대기 목록 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.9',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '방문일 선택에서도 전체 예약·본인 일정을 캘린더처럼 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세는 같은 주소의 이전 접수·견적만 보여 잘못된 견적 표시를 줄였습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '방문 주간표에 팀 이름 뱃지·색으로 1팀·2팀을 바로 구분합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '고객 대기(피드백·구두·발송 후) 카드를 누르면 같은 조건의 목록이 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 접수 칸에 미처리 건수를 같이 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.9'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '방문일 선택에서도 전체 예약·본인 일정을 캘린더처럼 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세는 같은 주소의 이전 접수·견적만 보여 잘못된 견적 표시를 줄였습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '방문 주간표에 팀 이름 뱃지·색으로 1팀·2팀을 바로 구분합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '고객 대기(피드백·구두·발송 후) 카드를 누르면 같은 조건으로 목록이 열립니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈 접수 칸에 미처리 건수를 같이 표시합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.9';

update public.app_update_policy
set
  latest_version = '1.9.9',
  updated_at = now()
where is_active = true;
