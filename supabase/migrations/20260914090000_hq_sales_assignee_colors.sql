-- 본사 영업부 달력 색을 서로 잘 구분되게 조정한다.
-- users.color 는 COAD_home 본사일반·앱 본사일반이 같이 사용한다.

update public.users set color = '#DC2626' where id = '김인엽'; -- 빨강
update public.users set color = '#EA580C' where id = '이상호'; -- 주황
update public.users set color = '#0F766E' where id = '이상수'; -- 청록
update public.users set color = '#2563EB' where id = '박정훈'; -- 파랑
update public.users set color = '#16A34A' where id = '권요한'; -- 초록
update public.users set color = '#C026D3' where id = '장일영'; -- 자홍
