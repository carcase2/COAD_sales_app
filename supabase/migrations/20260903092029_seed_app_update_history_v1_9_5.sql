-- v1.9.5: A/S 접수 앱 알림 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.5',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '인트라넷·앱에서 A/S(고객지원) 접수 시 고객지원팀·관리자 폰으로 알림이 갑니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '아이폰에서도 배너가 보이도록 알림 제목·본문을 함께 보냅니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.5'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '인트라넷·앱에서 A/S(고객지원) 접수 시 고객지원팀·관리자 폰으로 알림이 갑니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '아이폰에서도 배너가 보이도록 알림 제목·본문을 함께 보냅니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.5';

update public.app_update_policy
set
  latest_version = '1.9.5',
  updated_at = now()
where is_active = true;
