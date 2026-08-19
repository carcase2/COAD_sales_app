ALTER TABLE public.standard_unit_prices
  DROP CONSTRAINT IF EXISTS standard_unit_prices_width_mm_check;
ALTER TABLE public.standard_unit_prices
  DROP CONSTRAINT IF EXISTS standard_unit_prices_height_mm_check;

ALTER TABLE public.standard_unit_prices
  ADD CONSTRAINT standard_unit_prices_width_mm_check
  CHECK (width_mm >= 1000 AND width_mm <= 10000);
ALTER TABLE public.standard_unit_prices
  ADD CONSTRAINT standard_unit_prices_height_mm_check
  CHECK (height_mm >= 1000 AND height_mm <= 10000);

DELETE FROM public.standard_unit_prices p
USING public.standard_unit_price_models m
JOIN public.standard_unit_price_categories c ON c.id = m.category_id
WHERE p.model_id = m.id AND c.name = '차고문';

WITH prices(model_name, width_mm, height_mm, price) AS (
  VALUES
    ('STANDARD(우드판넬)', 4000, 2150, 3200000),
    ('STANDARD(우드판넬)', 5000, 2150, 3400000),
    ('STANDARD(우드판넬)', 6300, 2150, 4000000),
    ('STANDARD(우드판넬)', 4000, 2700, 3600000),
    ('STANDARD(우드판넬)', 5000, 2700, 4200000),
    ('STANDARD(우드판넬)', 6300, 2700, 4900000),
    ('DELUEX(다크 그레이,브라운)', 4000, 2150, 3900000),
    ('DELUEX(다크 그레이,브라운)', 5000, 2150, 4200000),
    ('DELUEX(다크 그레이,브라운)', 6300, 2150, 4800000),
    ('DELUEX(다크 그레이,브라운)', 4000, 2700, 4200000),
    ('DELUEX(다크 그레이,브라운)', 5000, 2700, 4500000),
    ('DELUEX(다크 그레이,브라운)', 6300, 2700, 5100000),
    ('PREMIUM(샤틴펄)', 4000, 2150, 5800000),
    ('PREMIUM(샤틴펄)', 5000, 2150, 6200000),
    ('PREMIUM(샤틴펄)', 6300, 2150, 6600000),
    ('PREMIUM(샤틴펄)', 4000, 2700, 6200000),
    ('PREMIUM(샤틴펄)', 5000, 2700, 6800000),
    ('PREMIUM(샤틴펄)', 6300, 2700, 7500000),
    ('PREMIUM(마블스톤)', 4000, 2150, 6800000),
    ('PREMIUM(마블스톤)', 5000, 2150, 7200000),
    ('PREMIUM(마블스톤)', 6300, 2150, 7600000),
    ('PREMIUM(마블스톤)', 4000, 2700, 7200000),
    ('PREMIUM(마블스톤)', 5000, 2700, 7800000),
    ('PREMIUM(마블스톤)', 6300, 2700, 8500000)
)
INSERT INTO public.standard_unit_prices (model_id, width_mm, height_mm, price, available)
SELECT m.id, prices.width_mm, prices.height_mm, prices.price, true
FROM prices
JOIN public.standard_unit_price_models m ON m.name = prices.model_name
JOIN public.standard_unit_price_categories c ON c.id = m.category_id AND c.name = '차고문'
ON CONFLICT (model_id, width_mm, height_mm)
DO UPDATE SET price = EXCLUDED.price, available = true, updated_at = now();
