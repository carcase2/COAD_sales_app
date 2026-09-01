-- v1.8.5: 고객지원 A/S 단가표 검색·이력 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.8.5',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 접수·팔로우업 중 A/S 단가표를 검색할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'WMS·SPD·OHD 부품 175종과 인건비 58종이 2026.03.06 단가 기준으로 들어 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '부품 사진·도해를 단가표에서 바로 볼 수 있고, 사진을 바꾸거나 추가할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가 추가·수정·삭제가 되고, 누가 어떻게 바꿨는지 이력이 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.8.5'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 접수·팔로우업 중 A/S 단가표를 검색할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'WMS·SPD·OHD 부품 175종과 인건비 58종이 2026.03.06 단가 기준으로 들어 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '부품 사진·도해를 단가표에서 바로 볼 수 있고, 사진을 바꾸거나 추가할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가 추가·수정·삭제가 되고, 누가 어떻게 바꿨는지 이력이 남습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.8.5';

update public.app_update_policy
set
  latest_version = '1.8.5',
  updated_at = now()
where is_active = true;
