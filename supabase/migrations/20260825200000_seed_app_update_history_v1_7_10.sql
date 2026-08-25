-- v1.7.10: 표준단가 키패드 버튼 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.10',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 폭 지움·높이 지움·폭으로 버튼을 키워 아이폰에서도 누르기 쉽게 했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.10'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 폭 지움·높이 지움·폭으로 버튼을 키워 아이폰에서도 누르기 쉽게 했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.10';

update public.app_update_policy
set
  latest_version = '1.7.10',
  updated_at = now()
where is_active = true;
