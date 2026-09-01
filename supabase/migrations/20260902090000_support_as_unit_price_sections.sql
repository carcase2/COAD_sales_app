-- A/S 단가: 타사 단가 컬럼, 큰분류·작은분류 관리 테이블.
-- 기존 비고의 `타사 80,000원`을 competitor_price로 옮긴다.

ALTER TABLE public.support_as_unit_prices
  ADD COLUMN IF NOT EXISTS competitor_price integer
    CHECK (competitor_price IS NULL OR competitor_price >= 0);

COMMENT ON COLUMN public.support_as_unit_prices.competitor_price IS '타사 단가';

UPDATE public.support_as_unit_prices
SET competitor_price = replace(
  (regexp_match(note, '타사[[:space:]]*([0-9,]+)[[:space:]]*원'))[1],
  ',',
  ''
)::integer
WHERE competitor_price IS NULL
  AND note ~ '타사[[:space:]]*[0-9,]+[[:space:]]*원';

UPDATE public.support_as_unit_prices
SET note = trim(both FROM
  regexp_replace(
    regexp_replace(
      note,
      '(^|[[:space:]]*·[[:space:]]*)타사[[:space:]]*[0-9,]+[[:space:]]*원',
      '',
      'g'
    ),
    '^[[:space:]]*·[[:space:]]*|[[:space:]]*·[[:space:]]*$',
    '',
    'g'
  )
)
WHERE note ~ '타사[[:space:]]*[0-9,]+[[:space:]]*원';

CREATE TABLE IF NOT EXISTS public.support_as_unit_price_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_line text NOT NULL,
  category text NOT NULL DEFAULT '',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT support_as_unit_price_sections_line_cat_key
    UNIQUE (product_line, category)
);

CREATE INDEX IF NOT EXISTS support_as_unit_price_sections_line_idx
  ON public.support_as_unit_price_sections (product_line, sort_order);

COMMENT ON TABLE public.support_as_unit_price_sections IS
  'A/S 단가 큰분류(product_line)·작은분류(category). 품목 없이도 분류를 추가·수정·삭제한다.';

INSERT INTO public.support_as_unit_price_sections (product_line, category, sort_order)
SELECT product_line, category, MIN(sort_order)
FROM public.support_as_unit_prices
WHERE deleted_at IS NULL
  AND product_line <> ''
GROUP BY product_line, category
ON CONFLICT (product_line, category) DO NOTHING;

ALTER TABLE public.support_as_unit_price_sections ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_as_unit_price_sections'
      AND policyname = 'support_as_unit_price_sections_all'
  ) THEN
    CREATE POLICY support_as_unit_price_sections_all
      ON public.support_as_unit_price_sections
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_as_unit_price_sections
  TO anon, authenticated;
