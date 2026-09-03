-- v1.9.3: A/S 방문 팀·입금일·이행증권 같이 요청 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.3',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 본사·지사별 A/S 방문 팀을 두고 방문일·시간에 맞춰 배정할 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '유상 입금은 예정일과 실제 입금일을 따로 남길 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '이행증권 계약이행과 선급금을 한 번에 요청할 수 있습니다. 업체·첨부는 공유하고 보증금율·기간만 종류별로 넣습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 상세에서 종료 표시가 화면을 넘치지 않습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.3'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '고객지원팀이 본사·지사별 A/S 방문 팀을 두고 방문일·시간에 맞춰 배정할 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '유상 입금은 예정일과 실제 입금일을 따로 남길 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '이행증권 계약이행과 선급금을 한 번에 요청할 수 있습니다. 업체·첨부는 공유하고 보증금율·기간만 종류별로 넣습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '자동문의고수 상세에서 종료 표시가 화면을 넘치지 않습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.3';

update public.app_update_policy
set
  latest_version = '1.9.3',
  updated_at = now()
where is_active = true;
