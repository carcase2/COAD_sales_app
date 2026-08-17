-- v1.4.3: 내 발급요청 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.4.3',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청에서 내가 요청한 대기·발급됨만 바로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '현장명·번호로 검색하고, 잔여 %를 이어서 요청할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '최근 내 요청을 불러와 같은 현장을 빠르게 등록합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.4.3'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청에서 내가 요청한 대기·발급됨만 바로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '현장명·번호로 검색하고, 잔여 %를 이어서 요청할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '최근 내 요청을 불러와 같은 현장을 빠르게 등록합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.4.3';

update public.app_update_policy
set
  latest_version = '1.4.3',
  updated_at = now()
where is_active = true;
