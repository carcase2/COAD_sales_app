-- v1.14.2: 표준단가 견적 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.14.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '표준단가 견적을 기본 견적과 세부 견적(본체·센서·시공비·운반장비대)으로 작성합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '목표 단가와 표준단가 차이를 작성 중에 보고, 고객 견적서에는 표준단가를 찍지 않습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '같은 모델의 다른 사이즈를 한 장에 넣고, 세트 수량만큼 세부 항목도 늘어납니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '저장만 하거나 이미지·PDF·메일로 보내고, 목록에서 현장명·작성자·날짜를 봅니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.14.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '표준단가 견적을 기본 견적과 세부 견적(본체·센서·시공비·운반장비대)으로 작성합니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '목표 단가와 표준단가 차이를 작성 중에 보고, 고객 견적서에는 표준단가를 찍지 않습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '같은 모델의 다른 사이즈를 한 장에 넣고, 세트 수량만큼 세부 항목도 늘어납니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '저장만 하거나 이미지·PDF·메일로 보내고, 목록에서 현장명·작성자·날짜를 봅니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.14.2';

update public.app_update_policy
set
  latest_version = '1.14.2',
  updated_at = now()
where is_active = true;
