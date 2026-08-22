-- v1.7.3: 메일 발송 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '메뉴에서 메일 발송을 열고 자료실 파일을 골라 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '받는 사람은 명함에서 고르고, 보내는 사람은 로그인 계정으로 고정됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '보낸 메일에서 다시 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.3'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '메뉴에서 메일 발송을 열고 자료실 파일을 골라 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '받는 사람은 명함에서 고르고, 보내는 사람은 로그인 계정으로 고정됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '보낸 메일에서 다시 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.3';

update public.app_update_policy
set
  latest_version = '1.7.3',
  updated_at = now()
where is_active = true;
