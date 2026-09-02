-- 고객지원 A/S 견적서. 단가표에서 품목을 가져와 작성하고, 현장·전화로 검색한다.

CREATE TABLE IF NOT EXISTS public.support_as_quotes (
  id text PRIMARY KEY,
  quote_no text NOT NULL DEFAULT '',
  ymd date,
  customer_name text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  site text NOT NULL DEFAULT '',
  address text NOT NULL DEFAULT '',
  work_name text NOT NULL DEFAULT '',
  lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  note text NOT NULL DEFAULT '',
  total integer NOT NULL DEFAULT 0,
  sent_ymd date,
  call_log_id text,
  created_by text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  search_text text NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS support_as_quotes_ymd_idx
  ON public.support_as_quotes (ymd DESC NULLS LAST, created_at DESC);
CREATE INDEX IF NOT EXISTS support_as_quotes_phone_idx
  ON public.support_as_quotes (phone);
CREATE INDEX IF NOT EXISTS support_as_quotes_site_idx
  ON public.support_as_quotes (site);
CREATE INDEX IF NOT EXISTS support_as_quotes_quote_no_idx
  ON public.support_as_quotes (quote_no);

ALTER TABLE public.support_as_quotes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_as_quotes_all ON public.support_as_quotes;
CREATE POLICY support_as_quotes_all
  ON public.support_as_quotes
  FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_as_quotes TO anon, authenticated;

COMMENT ON TABLE public.support_as_quotes IS '고객지원 A/S 견적서. 부품·인건비·장비대 품목, 현장 히스토리 검색.';
