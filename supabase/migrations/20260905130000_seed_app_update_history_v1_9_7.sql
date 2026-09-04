-- v1.9.7: A/S 견적서 네고·클라우드 PDF (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.7',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'A/S 견적서에 네고(%·금액)를 넣고 소계·네고·합계가 보입니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '견적서 작성·수정 이력이 남고, 작성자·수정자·발송일을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'PDF 저장·공유 시 클라우드에도 올려 생성일·작성자·수정자·발송일을 함께 보관합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세·오늘 데스크·자동문의고수 상세 화면을 쓰기 쉽게 정리했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.7'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'A/S 견적서에 네고(%·금액)를 넣고 소계·네고·합계가 보입니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '견적서 작성·수정 이력이 남고, 작성자·수정자·발송일을 확인할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      'PDF 저장·공유 시 클라우드에도 올려 생성일·작성자·수정자·발송일을 함께 보관합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '접수 상세·오늘 데스크·자동문의고수 상세 화면을 쓰기 쉽게 정리했습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.7';

update public.app_update_policy
set
  latest_version = '1.9.7',
  updated_at = now()
where is_active = true;
