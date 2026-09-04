-- A/S 견적서 네고(할인) 금액·비율
ALTER TABLE public.support_as_quotes
  ADD COLUMN IF NOT EXISTS nego_amount integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nego_percent numeric NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.support_as_quotes.nego_amount IS '네고 할인 금액(원). percent와 배타적으로 사용.';
COMMENT ON COLUMN public.support_as_quotes.nego_percent IS '네고 할인율(%). amount와 배타적으로 사용.';
