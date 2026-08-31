-- v1.8.2: 자동문의고수 담당자 선택 복구 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.8.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수에서 담당자를 다시 고를 수 있습니다 (선택 사항)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자 목록은 인트라넷과 같이 자동문의고수 부서만 나옵니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.8.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수에서 담당자를 다시 고를 수 있습니다 (선택 사항)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자 목록은 인트라넷과 같이 자동문의고수 부서만 나옵니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.8.2';

update public.app_update_policy
set
  latest_version = '1.8.2',
  updated_at = now()
where is_active = true;
