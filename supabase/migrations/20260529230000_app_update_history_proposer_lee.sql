-- 업데이트 내역 제안자: 이상수 팀장 요청 반영 (v0.16.22 ~)

update public.app_update_history
set proposer = '이상수 팀장'
where version in (
  '0.16.22',
  '0.16.23',
  '0.16.24',
  '0.16.25',
  '0.16.26',
  '0.16.27',
  '0.16.28'
);
