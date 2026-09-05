-- v1.9.8: A/S 방문 주간표·2시간 전 알림 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.8',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'A/S 방문 주간표는 월~금만 보이고, 일정·팀 색으로 바로 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '일정 변경 시 이전·변경 일정을 확인한 뒤 저장합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '방문 예정 2시간 전 로컬 알림으로 준비를 돕습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세에서 방문일·시간이 잘리지 않고, 주간표 하단이 안드로이드 버튼에 가리지 않습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.8'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'A/S 방문 주간표는 월~금만 보이고, 일정·팀 색으로 바로 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '일정 변경 시 이전·변경 일정을 확인한 뒤 저장합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '방문 예정 2시간 전 로컬 알림으로 준비를 돕습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세에서 방문일·시간이 잘리지 않고, 주간표 하단이 안드로이드 버튼에 가리지 않습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.8';

update public.app_update_policy
set
  latest_version = '1.9.8',
  updated_at = now()
where is_active = true;
