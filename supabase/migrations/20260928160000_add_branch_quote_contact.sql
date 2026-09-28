-- 견적서에 찍는 지사별 주소와 메일.

ALTER TABLE public.coad_branch
  ADD COLUMN IF NOT EXISTS quote_address text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS quote_email text NOT NULL DEFAULT '';

UPDATE public.coad_branch
SET
  quote_address = '경기도 화성시 남양읍 현대기아로 202-37',
  quote_email = 'sales@coaddoor.com'
WHERE name = '본사' AND quote_address = '';

UPDATE public.coad_branch
SET
  quote_address = '대구광역시 달성군 논공읍 금강로4길 21',
  quote_email = 'coaddg@coaddoor.com'
WHERE name IN ('대구지사', '영남지사') AND quote_address = '';

UPDATE public.coad_branch
SET
  quote_address = '충북 청주시 서원구 현도면 시목외천로137,2동',
  quote_email = 'coaddj@coaddoor.com'
WHERE name = '중부지사' AND quote_address = '';

UPDATE public.coad_branch
SET
  quote_address = '전라남도 나주시 산포면 내길1길 36',
  quote_email = 'coadjn@coaddoor.com'
WHERE name = '전남지사' AND quote_address = '';
