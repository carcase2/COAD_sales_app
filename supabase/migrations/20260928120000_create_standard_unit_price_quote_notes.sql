-- 영업 견적서 NOTE. 공통 1–7과 모델별 사양(8번~)을 따로 고친다.
-- 견적서 한 건의 추가 메모(note)와는 별개다.

CREATE TABLE IF NOT EXISTS public.standard_unit_price_quote_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL CHECK (scope IN ('common', 'model')),
  category_name text NOT NULL DEFAULT '',
  model_name text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scope, category_name, model_name)
);

CREATE INDEX IF NOT EXISTS standard_unit_price_quote_notes_scope_idx
  ON public.standard_unit_price_quote_notes (scope, category_name, model_name);

ALTER TABLE public.standard_unit_price_quote_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS standard_unit_price_quote_notes_all
  ON public.standard_unit_price_quote_notes;
CREATE POLICY standard_unit_price_quote_notes_all
  ON public.standard_unit_price_quote_notes
  FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.standard_unit_price_quote_notes TO anon, authenticated;

COMMENT ON TABLE public.standard_unit_price_quote_notes IS
  '영업 견적서 노트. scope=common 은 공통 NOTE, scope=model 은 분류+모델 사양.';
