-- v1.9.4: 이행증권 요청 화면 정리 (제안: 이상수 팀장)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.9.4',
  '이상수 팀장',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '이행증권 보증/기간을 증권 종류별 카드로 맞춰, 계약이행·선급금·하자이행을 같은 형식으로 입력합니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '시공 시작일·종료일을 한 줄로 고를 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '발급요청 등록에서 세금계산서·이행증권 탭이 화면을 넘치지 않습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.9.4'
);

update public.app_update_history
set
  proposer = '이상수 팀장',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      '이행증권 보증/기간을 증권 종류별 카드로 맞춰, 계약이행·선급금·하자이행을 같은 형식으로 입력합니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '시공 시작일·종료일을 한 줄로 고를 수 있습니다',
      'proposer',
      '이상수 팀장'
    ),
    jsonb_build_object(
      'note',
      '발급요청 등록에서 세금계산서·이행증권 탭이 화면을 넘치지 않습니다',
      'proposer',
      '이상수 팀장'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.9.4';

update public.app_update_policy
set
  latest_version = '1.9.4',
  updated_at = now()
where is_active = true;
