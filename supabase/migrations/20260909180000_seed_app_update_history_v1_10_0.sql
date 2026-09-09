-- v1.10.0: 시공 사진 검색·표준단가 견적서 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.10.0',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '시공 사진에서 C-1·C-50 같은 모델로 시공후 사진만 찾습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '현장은 MES 품목(COAD) 기준으로 최근 연도 건이 함께 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '관리자는 누가 시공 사진을 얼마나 검색했는지 기간별로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가·셔터 견적에서 바로 견적서를 작성하고 PDF·메일로 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.10.0'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '시공 사진에서 C-1·C-50 같은 모델로 시공후 사진만 찾습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '현장은 MES 품목(COAD) 기준으로 최근 연도 건이 함께 나옵니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '관리자는 누가 시공 사진을 얼마나 검색했는지 기간별로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가·셔터 견적에서 바로 견적서를 작성하고 PDF·메일로 보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.10.0';

update public.app_update_policy
set
  latest_version = '1.10.0',
  updated_at = now()
where is_active = true;
