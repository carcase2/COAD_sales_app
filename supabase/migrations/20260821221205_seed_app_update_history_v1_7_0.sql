-- v1.7.0: 고객지원 A/S (제안: 남현우 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.0',
  '남현우 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원 A/S 접수·상담·방문 기록을 앱에서 처리할 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '방문·발송 예정 캘린더와 알림을 확인할 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '고객지원 견적서·단가표와 현장 지도를 쓸 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적서를 이미지·PDF로 저장하고 이메일로 보낼 수 있습니다',
      'proposer',
      '남현우 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.0'
);

update public.app_update_history
set
  proposer = '남현우 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원 A/S 접수·상담·방문 기록을 앱에서 처리할 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '방문·발송 예정 캘린더와 알림을 확인할 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '고객지원 견적서·단가표와 현장 지도를 쓸 수 있습니다',
      'proposer',
      '남현우 팀장'
    ),
    jsonb_build_object(
      'note',
      '견적서를 이미지·PDF로 저장하고 이메일로 보낼 수 있습니다',
      'proposer',
      '남현우 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.0';

-- iOS 전용으로 숨겼던 중간 버전은 그대로 두고, 최신 안내만 1.7.0으로 맞춘다.
update public.app_update_policy
set
  latest_version = '1.7.0',
  updated_at = now()
where is_active = true;
