-- v1.15.0: 업무 수정·실행 취소·접수로 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.15.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '업무 상세에서 제목·기한·중요도·담당·내용·요청인을 고칠 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무 시작·완료·보류를 누른 뒤 「실행 취소」로 되돌릴 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '진행중·보류 업무를 「접수로 되돌리기」 할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.15.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '업무 상세에서 제목·기한·중요도·담당·내용·요청인을 고칠 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '업무 시작·완료·보류를 누른 뒤 「실행 취소」로 되돌릴 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '진행중·보류 업무를 「접수로 되돌리기」 할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.15.0';

update public.app_update_policy
set
  latest_version = '1.15.0',
  updated_at = now()
where is_active = true;
