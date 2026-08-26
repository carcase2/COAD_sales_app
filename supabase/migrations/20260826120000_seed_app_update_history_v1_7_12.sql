-- v1.7.12: 표준단가 직접 입력 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.12',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 폭·높이를 키패드로 직접 넣고, 칸을 다시 누르면 지우고 다시 입력할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '금액이 나오면 복사 버튼을 바로 누를 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.12'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 폭·높이를 키패드로 직접 넣고, 칸을 다시 누르면 지우고 다시 입력할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '금액이 나오면 복사 버튼을 바로 누를 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.12';

update public.app_update_policy
set
  latest_version = '1.7.12',
  updated_at = now()
where is_active = true;
