-- v1.4.2: 고객전화 현장 편의 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.4.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 후 해당 건 상세로 바로 이동하고, 같은 번호 기존 접수를 안내합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상담 예정일을 오늘·내일·모레·다음 주 칩으로 빠르게 고를 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈에 지연 팔로우를 모으고, 목록에서 직전 상담·상담 입력이 가능합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.4.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '접수 후 해당 건 상세로 바로 이동하고, 같은 번호 기존 접수를 안내합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '상담 예정일을 오늘·내일·모레·다음 주 칩으로 빠르게 고를 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈에 지연 팔로우를 모으고, 목록에서 직전 상담·상담 입력이 가능합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.4.2';

update public.app_update_policy
set
  latest_version = '1.4.2',
  updated_at = now()
where is_active = true;
