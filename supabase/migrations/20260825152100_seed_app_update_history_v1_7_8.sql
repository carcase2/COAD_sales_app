-- v1.7.8: 사이즈 표준단가 비교 (제안: 김경덕 이사)
-- iOS 전용 배포. Android 스토어는 1.7.7이므로 latest_version은 유지한다.

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.8',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 자주 쓰는 폭·높이를 바로 고르고 숫자 키패드로 입력할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '같은 사이즈로 다른 모델 단가를 비교하고, 견적 한 줄을 복사·공유할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.8'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 자주 쓰는 폭·높이를 바로 고르고 숫자 키패드로 입력할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '같은 사이즈로 다른 모델 단가를 비교하고, 견적 한 줄을 복사·공유할 수 있습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.8';
