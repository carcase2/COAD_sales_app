-- v1.14.8: 명함 수첩 바로 연락·연락처 저장·정렬 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.8',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 목록에서 바로 전화하고, 길게 누르면 문자·번호 복사가 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '명함을 휴대폰 연락처에 저장하거나 카톡·문자로 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '명함 목록을 최근순·이름순·회사별로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.8'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '명함 목록에서 바로 전화하고, 길게 누르면 문자·번호 복사가 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '명함을 휴대폰 연락처에 저장하거나 카톡·문자로 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '명함 목록을 최근순·이름순·회사별로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.8';

update public.app_update_policy
set
  latest_version = '1.14.8',
  updated_at = now()
where is_active = true;
