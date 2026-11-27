-- v1.18.1: 계약서 탭·명함 자동 등록·명함 스캐너 (제안: 김경덕 이사)
-- v1.18.0(빌드 216)과 v1.18.1(빌드 217)을 한 줄로 남긴다.
-- app_update_policy.latest_version 은 건드리지 않는다: 아직 내부 테스트 트랙에만 있어
-- 올리면 스토어에서 받을 수 없는 버전으로 업데이트를 안내하게 된다. 정식 출시 때 올린다.

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.18.1',
  '김경덕 이사',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      '발급요청에 계약서 탭을 더했습니다 (세금계산서·이행증권·계약서). 계약서 작성 요청 목록과 요청하기를 한 화면에서 씁니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '계약서 작성 요청에 명함 사진을 올리면 발주자 칸을 채우고 명함첩에 바로 등록합니다 (같은 연락처가 있으면 새로 만들지 않음)',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '명함 촬영이 기기 문서 스캐너로 명함 테두리를 자동으로 잡습니다',
      'proposer',
      '김경덕 이사'
    ),
    jsonb_build_object(
      'note',
      '지역번호 전화번호가 055-343-7715처럼 바르게 표시되고, 7715~6 같은 대표번호 범위도 바르게 읽습니다',
      'proposer',
      '김경덕 이사'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.18.1'
);
