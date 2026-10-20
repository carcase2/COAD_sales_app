-- v1.14.4: 단열 20mm·22mm 셔터박스·브라켓 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '단열 셔터는 비와이메탈 22mm, 명진 20mm로 셔터박스와 브라켓이 나뉩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '20mm는 같은 박스를 300mm 더 높은 개구까지 씁니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '기술 사양에서 비와이메탈·명진을 고르면 제조사 비교에도 같이 적용됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단열 2구간에는 주문형 브라켓이 표시됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.4'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '단열 셔터는 비와이메탈 22mm, 명진 20mm로 셔터박스와 브라켓이 나뉩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '20mm는 같은 박스를 300mm 더 높은 개구까지 씁니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '기술 사양에서 비와이메탈·명진을 고르면 제조사 비교에도 같이 적용됩니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단열 2구간에는 주문형 브라켓이 표시됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.4';

update public.app_update_policy
set
  latest_version = '1.14.4',
  updated_at = now()
where is_active = true;
