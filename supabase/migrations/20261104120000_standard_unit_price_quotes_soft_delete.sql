-- 견적서 통합(견적 탭 = 견적서 목록) 후속.
-- 1) 지운 견적서를 바로 없애지 않고 표시만 한다. 앱은 deleted_at IS NULL만 보여준다.
-- 2) 견적번호는 하나만. 동시에 같은 번호를 잡으면 앱이 다음 번호로 다시 저장한다.

ALTER TABLE public.standard_unit_price_quotes
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS standard_unit_price_quotes_live_idx
  ON public.standard_unit_price_quotes (ymd DESC NULLS LAST, created_at DESC)
  WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS standard_unit_price_quotes_quote_no_key
  ON public.standard_unit_price_quotes (quote_no)
  WHERE quote_no <> '';

COMMENT ON COLUMN public.standard_unit_price_quotes.deleted_at IS
  '지운 시각. 값이 있으면 목록에서 숨긴다(복구는 NULL로).';
