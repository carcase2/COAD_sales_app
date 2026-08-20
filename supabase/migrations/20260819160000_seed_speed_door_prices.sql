ALTER TABLE public.standard_unit_prices
  ADD COLUMN IF NOT EXISTS available boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.standard_unit_prices.available IS 'false면 해당 폭×높이는 불가 사이즈(X)';

UPDATE public.standard_unit_price_models m
SET name = 'VE STANDARD(S)', updated_at = now()
FROM public.standard_unit_price_categories c
WHERE m.category_id = c.id AND c.name = '스피드도어' AND m.name = 'VE STANDARD'
  AND NOT EXISTS (
    SELECT 1
    FROM public.standard_unit_price_models existing
    WHERE existing.category_id = m.category_id
      AND existing.name = 'VE STANDARD(S)'
  );

UPDATE public.standard_unit_price_models m
SET name = 'DELUXE', updated_at = now()
FROM public.standard_unit_price_categories c
WHERE m.category_id = c.id AND c.name = '스피드도어' AND m.name = 'DELUEX'
  AND NOT EXISTS (
    SELECT 1
    FROM public.standard_unit_price_models existing
    WHERE existing.category_id = m.category_id
      AND existing.name = 'DELUXE'
  );

UPDATE public.standard_unit_prices p
SET available = false, price = 0, updated_at = now()
FROM public.standard_unit_price_models m
JOIN public.standard_unit_price_categories c ON c.id = m.category_id
WHERE p.model_id = m.id AND c.name = '스피드도어';

WITH prices(model_name, width_mm, height_mm, price) AS (
  VALUES
    ('VE STANDARD(S)', 2000, 2000, 3500000),
    ('VE STANDARD(S)', 3000, 3000, 3800000),
    ('VE STANDARD(S)', 3000, 4000, 4000000),
    ('VE STANDARD(S)', 4000, 4000, 4300000),
    ('STANDARD', 2000, 2000, 4300000),
    ('STANDARD', 3000, 3000, 4800000),
    ('STANDARD', 3000, 4000, 5400000),
    ('STANDARD', 4000, 4000, 5800000),
    ('STANDARD', 5000, 4000, 6300000),
    ('STANDARD', 5000, 5000, 6800000),
    ('DELUXE', 2000, 2000, 4800000),
    ('DELUXE', 3000, 3000, 5300000),
    ('DELUXE', 3000, 4000, 5900000),
    ('DELUXE', 4000, 4000, 6300000),
    ('PREMIUM', 2000, 2000, 6300000),
    ('PREMIUM', 3000, 3000, 6800000),
    ('PREMIUM', 3000, 4000, 7400000),
    ('PREMIUM', 4000, 4000, 7800000),
    ('PREMIUM', 5000, 4000, 8300000),
    ('PREMIUM', 5000, 5000, 8800000),
    ('PREMIUM', 6000, 5000, 10000000),
    ('PREMIUM', 7000, 5000, 14000000),
    ('PREMIUM', 8000, 5000, 17000000)
)
UPDATE public.standard_unit_prices p
SET price = prices.price, available = true, updated_at = now()
FROM prices
JOIN public.standard_unit_price_models m ON m.name = prices.model_name
JOIN public.standard_unit_price_categories c ON c.id = m.category_id AND c.name = '스피드도어'
WHERE p.model_id = m.id
  AND p.width_mm = prices.width_mm
  AND p.height_mm = prices.height_mm;
