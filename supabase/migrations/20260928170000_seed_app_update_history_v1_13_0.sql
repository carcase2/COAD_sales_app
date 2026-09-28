-- v1.13.0: 영업 견적서 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.13.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적서 미리보기에서 용지 전체를 보고 두 손가락으로 확대할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자 이름·휴대폰, 지사별 주소·메일, 로고·도장을 넣었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '가산율과 가산 금액을 함께 적용하고, 공통·모델 노트를 관리합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.13.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '견적서 미리보기에서 용지 전체를 보고 두 손가락으로 확대할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '담당자 이름·휴대폰, 지사별 주소·메일, 로고·도장을 넣었습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '가산율과 가산 금액을 함께 적용하고, 공통·모델 노트를 관리합니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.13.0';

update public.app_update_policy
set
  latest_version = '1.13.0',
  updated_at = now()
where is_active = true;
