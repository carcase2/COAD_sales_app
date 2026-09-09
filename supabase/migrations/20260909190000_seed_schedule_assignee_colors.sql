-- 본사일반·대구지사 달력 담당자 색. users.color 가 화면 색의 기준이다.

alter table public.users
  add column if not exists color text;

comment on column public.users.color is
  '담당자 달력 색 (#RRGGBB). 본사일반·대구지사 일정이 이 값을 사용한다.';

-- 본사영업
update public.users set color = '#1D4ED8' where id = '김인엽';
update public.users set color = '#059669' where id = '이상호';
update public.users set color = '#0891B2' where id = '이상수';
update public.users set color = '#4F46E5' where id = '박정훈';
update public.users set color = '#65A30D' where id = '권요한';
update public.users set color = '#9333EA' where id = '장일영';

-- 대구지사장·대구지사
update public.users set color = '#D97706' where id = '이영석';
update public.users set color = '#0369A1' where id = '우상덕';
update public.users set color = '#B45309' where id = '김용';
update public.users set color = '#15803D' where id = '강준혁';
update public.users set color = '#1E3A8A' where id = '김재백';
update public.users set color = '#9F1239' where id = '김재성';
update public.users set color = '#155E75' where id = '김현진';
update public.users set color = '#7C2D12' where id = '박진영';

-- 관리자·본사일반에 일정이 있는 시공파트장
update public.users set color = '#EA580C' where id = '관리자';
update public.users set color = '#7C3AED' where id = '유성준';
update public.users set color = '#DB2777' where id = '김경덕';
update public.users set color = '#BE123C' where id = '허만';
update public.users set color = '#0F766E' where id = '신형준';
