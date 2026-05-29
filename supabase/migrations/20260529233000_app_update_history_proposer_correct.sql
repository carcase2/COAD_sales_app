-- 제안자 정정: 0.16.28·0.16.29만 이상수 팀장, 그 외는 개발팀

update public.app_update_history
set proposer = '개발팀'
where version in (
  '0.16.21',
  '0.16.22',
  '0.16.23',
  '0.16.24',
  '0.16.25',
  '0.16.26',
  '0.16.27'
);

update public.app_update_history
set proposer = '이상수 팀장'
where version in ('0.16.28', '0.16.29');
