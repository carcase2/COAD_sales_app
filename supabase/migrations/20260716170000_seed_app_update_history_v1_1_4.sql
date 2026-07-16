-- v1.1.4: 관리자 그룹 알림 수신 개선 (제안: 정나영 실장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.1.4',
  '정나영 실장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자 그룹에 소속된 직원도 발급요청·발급완료 알림을 받도록 수정했습니다',
      'proposer',
      '정나영 실장'
    ),
    jsonb_build_object(
      'note',
      '관리자 그룹에 소속된 직원도 고객접수 알림을 받도록 수정했습니다',
      'proposer',
      '정나영 실장'
    ),
    jsonb_build_object(
      'note',
      '고객접수 담당자 미지정 시 전체 알림 대신 관리자만 수신하도록 정리했습니다',
      'proposer',
      '정나영 실장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.1.4'
);

update public.app_update_history
set
  proposer = '정나영 실장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '관리자 그룹에 소속된 직원도 발급요청·발급완료 알림을 받도록 수정했습니다',
      'proposer',
      '정나영 실장'
    ),
    jsonb_build_object(
      'note',
      '관리자 그룹에 소속된 직원도 고객접수 알림을 받도록 수정했습니다',
      'proposer',
      '정나영 실장'
    ),
    jsonb_build_object(
      'note',
      '고객접수 담당자 미지정 시 전체 알림 대신 관리자만 수신하도록 정리했습니다',
      'proposer',
      '정나영 실장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.1.4';

update public.app_update_policy
set
  latest_version = '1.1.4',
  updated_at = now()
where is_active = true;
