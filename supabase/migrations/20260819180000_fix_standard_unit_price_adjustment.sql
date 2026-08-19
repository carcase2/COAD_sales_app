-- 일괄 인상 시 1000mm 빈 격자를 만들지 않고, X/0원 칸은 올리지 않는다.

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
      AND coalesce(available, true) = true
      AND price > 0
  LOOP
    IF p_adjustment_type = 'percent' THEN
      v_new := ROUND(r.price * (1 + p_adjustment_value / 100.0));
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

-- 차고문에 잘못 생긴 1000mm 격자 칸 제거 (공식 사이즈만 유지)
DELETE FROM public.standard_unit_prices p
USING public.standard_unit_price_models m
JOIN public.standard_unit_price_categories c ON c.id = m.category_id
WHERE p.model_id = m.id
  AND c.name = '차고문'
  AND NOT (
    p.width_mm IN (4000, 5000, 6300)
    AND p.height_mm IN (2150, 2700)
  );
