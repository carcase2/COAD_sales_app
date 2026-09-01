-- v1.8.4: 자동문의고수 접수 사진·명함·선택 칩 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.8.4',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수에서 사진 앨범과 명함 인식을 쓸 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '제품군·문의방법·담당자 선택이 더 잘 구분됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.8.4'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '자동문의고수 접수에서 사진 앨범과 명함 인식을 쓸 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '제품군·문의방법·담당자 선택이 더 잘 구분됩니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.8.4';

update public.app_update_policy
set
  latest_version = '1.8.4',
  updated_at = now()
where is_active = true;
