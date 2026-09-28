-- 가산율과 가산 금액을 함께 저장한다. 예전 행은 markup_type으로 옮긴다.

ALTER TABLE public.standard_unit_price_quotes
  ADD COLUMN IF NOT EXISTS markup_percent numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS markup_amount integer NOT NULL DEFAULT 0;

UPDATE public.standard_unit_price_quotes
SET markup_percent = markup_value
WHERE markup_type = 'percent'
  AND markup_percent = 0
  AND markup_value <> 0;

UPDATE public.standard_unit_price_quotes
SET markup_amount = markup_value::integer
WHERE markup_type = 'amount'
  AND markup_amount = 0
  AND markup_value <> 0;
