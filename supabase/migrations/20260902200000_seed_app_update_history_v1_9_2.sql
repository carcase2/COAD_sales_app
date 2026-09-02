-- v1.9.2: A/S 견적서·전체 검색·답 대기 카드·피드백 대기 알림 (제안: 김경덕 이사)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.2',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 A/S 견적서를 작성하고 이미지·PDF로 저장·보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가표에서 품목을 바로 넣을 수 있고, 현장별로 견적서를 다시 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈·고객지원에 전체 카드가 있고, 완료된 현장도 검색·필터할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '답 대기·견적서를 따로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '피드백 대기는 2시간 뒤 다시 알림이 오고, 19시 이후는 다음날 9시입니다. 알림에 중요도가 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.2'
);

update public.app_update_history
set
  proposer = '김경덕 이사',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 A/S 견적서를 작성하고 이미지·PDF로 저장·보낼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '단가표에서 품목을 바로 넣을 수 있고, 현장별로 견적서를 다시 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '홈·고객지원에 전체 카드가 있고, 완료된 현장도 검색·필터할 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '답 대기·견적서를 따로 볼 수 있습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '피드백 대기는 2시간 뒤 다시 알림이 오고, 19시 이후는 다음날 9시입니다. 알림에 중요도가 보입니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.2';

update public.app_update_policy
set
  latest_version = '1.9.2',
  updated_at = now()
where is_active = true;
