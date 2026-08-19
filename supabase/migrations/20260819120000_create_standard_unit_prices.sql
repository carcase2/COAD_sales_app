-- 사이즈(폭×높이) × 모델 표준단가 (셔터 단가/외주시공비 격자와 별개)
-- 2000~8000mm, 1000mm 단위. 분류 아래 여러 모델.
-- 견적서 연동은 후속. 이번 단계는 표준단가 조회·통일·인상 이력.

CREATE TABLE IF NOT EXISTS public.standard_unit_price_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.standard_unit_price_models (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES public.standard_unit_price_categories(id) ON DELETE CASCADE,
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (category_id, name)
);

CREATE TABLE IF NOT EXISTS public.standard_unit_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL REFERENCES public.standard_unit_price_models(id) ON DELETE CASCADE,
  width_mm int NOT NULL CHECK (width_mm >= 2000 AND width_mm <= 8000 AND width_mm % 1000 = 0),
  height_mm int NOT NULL CHECK (height_mm >= 2000 AND height_mm <= 8000 AND height_mm % 1000 = 0),
  price numeric NOT NULL DEFAULT 0 CHECK (price >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (model_id, width_mm, height_mm)
);

CREATE TABLE IF NOT EXISTS public.standard_unit_price_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid REFERENCES public.standard_unit_price_models(id) ON DELETE SET NULL,
  category_id uuid REFERENCES public.standard_unit_price_categories(id) ON DELETE SET NULL,
  adjustment_type text NOT NULL CHECK (adjustment_type IN ('percent', 'amount', 'manual')),
  adjustment_value numeric NOT NULL DEFAULT 0,
  reason text NOT NULL,
  cells_affected int NOT NULL DEFAULT 0,
  user_id text NOT NULL DEFAULT '',
  user_name text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.standard_unit_price_change_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  adjustment_id uuid REFERENCES public.standard_unit_price_adjustments(id) ON DELETE SET NULL,
  model_id uuid REFERENCES public.standard_unit_price_models(id) ON DELETE SET NULL,
  width_mm int,
  height_mm int,
  old_price numeric NOT NULL,
  new_price numeric NOT NULL,
  change_type text NOT NULL CHECK (change_type IN ('percent', 'amount', 'manual')),
  reason text NOT NULL DEFAULT '',
  user_id text NOT NULL DEFAULT '',
  user_name text NOT NULL DEFAULT '',
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS standard_unit_prices_model_idx
  ON public.standard_unit_prices (model_id);
CREATE INDEX IF NOT EXISTS standard_unit_price_models_category_idx
  ON public.standard_unit_price_models (category_id, sort_order);
CREATE INDEX IF NOT EXISTS standard_unit_price_adjustments_created_idx
  ON public.standard_unit_price_adjustments (created_at DESC);
CREATE INDEX IF NOT EXISTS standard_unit_price_change_logs_model_idx
  ON public.standard_unit_price_change_logs (model_id, created_at DESC);
CREATE INDEX IF NOT EXISTS standard_unit_price_change_logs_adj_idx
  ON public.standard_unit_price_change_logs (adjustment_id);

COMMENT ON TABLE public.standard_unit_price_categories IS '표준단가 큰 분류 (방범, 철제방화 등)';
COMMENT ON TABLE public.standard_unit_price_models IS '표준단가 모델 (분류 하위)';
COMMENT ON TABLE public.standard_unit_prices IS '폭×높이 표준단가 - 2000~8000mm, 1000mm 단위';
COMMENT ON TABLE public.standard_unit_price_adjustments IS '모델별 일괄 인상/수정 배치 이력';
COMMENT ON TABLE public.standard_unit_price_change_logs IS '셀 단위 단가 변화 흐름';

ALTER TABLE public.standard_unit_price_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standard_unit_price_models ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standard_unit_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standard_unit_price_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.standard_unit_price_change_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'standard_unit_price_categories' AND policyname = 'standard_unit_price_categories_all') THEN
    CREATE POLICY standard_unit_price_categories_all ON public.standard_unit_price_categories FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'standard_unit_price_models' AND policyname = 'standard_unit_price_models_all') THEN
    CREATE POLICY standard_unit_price_models_all ON public.standard_unit_price_models FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'standard_unit_prices' AND policyname = 'standard_unit_prices_all') THEN
    CREATE POLICY standard_unit_prices_all ON public.standard_unit_prices FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'standard_unit_price_adjustments' AND policyname = 'standard_unit_price_adjustments_all') THEN
    CREATE POLICY standard_unit_price_adjustments_all ON public.standard_unit_price_adjustments FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'standard_unit_price_change_logs' AND policyname = 'standard_unit_price_change_logs_all') THEN
    CREATE POLICY standard_unit_price_change_logs_all ON public.standard_unit_price_change_logs FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.ensure_standard_unit_price_grid(p_model_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.standard_unit_prices (model_id, width_mm, height_mm, price)
  SELECT p_model_id, w, h, 0
  FROM generate_series(2000, 8000, 1000) AS w
  CROSS JOIN generate_series(2000, 8000, 1000) AS h
  ON CONFLICT (model_id, width_mm, height_mm) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_standard_unit_price_adjustment(
  p_model_id uuid,
  p_adjustment_type text,
  p_adjustment_value numeric,
  p_reason text,
  p_user_id text,
  p_user_name text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_adj_id uuid;
  v_count int := 0;
  v_cat uuid;
  r record;
  v_new numeric;
BEGIN
  IF p_model_id IS NULL THEN
    RAISE EXCEPTION '모델을 선택해 주세요.';
  END IF;
  IF p_adjustment_type NOT IN ('percent', 'amount') THEN
    RAISE EXCEPTION '인상 구분은 percent 또는 amount 입니다.';
  END IF;
  IF coalesce(trim(p_reason), '') = '' THEN
    RAISE EXCEPTION '인상 사유를 입력해 주세요.';
  END IF;

  SELECT category_id INTO v_cat
  FROM public.standard_unit_price_models
  WHERE id = p_model_id;

  IF v_cat IS NULL THEN
    RAISE EXCEPTION '모델을 찾을 수 없습니다.';
  END IF;

  PERFORM public.ensure_standard_unit_price_grid(p_model_id);

  INSERT INTO public.standard_unit_price_adjustments (
    model_id, category_id, adjustment_type, adjustment_value, reason,
    cells_affected, user_id, user_name
  ) VALUES (
    p_model_id, v_cat, p_adjustment_type, p_adjustment_value, trim(p_reason),
    0, coalesce(p_user_id, ''), coalesce(p_user_name, '')
  )
  RETURNING id INTO v_adj_id;

  FOR r IN
    SELECT id, price, width_mm, height_mm
    FROM public.standard_unit_prices
    WHERE model_id = p_model_id
  LOOP
    IF p_adjustment_type = 'percent' THEN
      IF r.price <= 0 THEN
        v_new := r.price;
      ELSE
        v_new := ROUND(r.price * (1 + p_adjustment_value / 100.0));
      END IF;
    ELSE
      v_new := GREATEST(0, ROUND(r.price + p_adjustment_value));
    END IF;

    IF v_new = r.price THEN
      CONTINUE;
    END IF;

    UPDATE public.standard_unit_prices
    SET price = v_new, updated_at = now()
    WHERE id = r.id;

    INSERT INTO public.standard_unit_price_change_logs (
      adjustment_id, model_id, width_mm, height_mm,
      old_price, new_price, change_type, reason, user_id, user_name
    ) VALUES (
      v_adj_id, p_model_id, r.width_mm, r.height_mm,
      r.price, v_new, p_adjustment_type, trim(p_reason),
      coalesce(p_user_id, ''), coalesce(p_user_name, '')
    );

    v_count := v_count + 1;
  END LOOP;

  UPDATE public.standard_unit_price_adjustments
  SET cells_affected = v_count
  WHERE id = v_adj_id;

  RETURN v_adj_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_standard_unit_price_grid(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_standard_unit_price_adjustment(uuid, text, numeric, text, text, text) TO anon, authenticated;

INSERT INTO public.standard_unit_price_categories (name, sort_order)
VALUES
  ('스피드도어', 10),
  ('차고문', 20)
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.standard_unit_price_models (category_id, name, sort_order)
SELECT c.id, v.name, v.sort_order
FROM public.standard_unit_price_categories c
JOIN (
  VALUES
    ('스피드도어', 'VE STANDARD', 10),
    ('스피드도어', 'STANDARD', 20),
    ('스피드도어', 'DELUEX', 30),
    ('스피드도어', 'PREMIUM', 40),
    ('차고문', 'STANDARD(우드판넬)', 10),
    ('차고문', 'DELUEX(다크 그레이,브라운)', 20),
    ('차고문', 'PREMIUM(샤틴펄)', 30),
    ('차고문', 'PREMIUM(마블스톤)', 40)
) AS v(category_name, name, sort_order) ON v.category_name = c.name
ON CONFLICT (category_id, name) DO NOTHING;

INSERT INTO public.standard_unit_prices (model_id, width_mm, height_mm, price)
SELECT m.id, w, h, 0
FROM public.standard_unit_price_models m
CROSS JOIN generate_series(2000, 8000, 1000) AS w
CROSS JOIN generate_series(2000, 8000, 1000) AS h
ON CONFLICT (model_id, width_mm, height_mm) DO NOTHING;
