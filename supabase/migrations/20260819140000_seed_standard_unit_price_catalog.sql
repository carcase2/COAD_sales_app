-- 표준단가 초기 분류/모델: 스피드도어, 차고문
DELETE FROM public.standard_unit_price_categories
WHERE name IN ('방범', '철제방화', '스크린방화');

INSERT INTO public.standard_unit_price_categories (name, sort_order)
VALUES
  ('스피드도어', 10),
  ('차고문', 20)
ON CONFLICT (name) DO UPDATE SET sort_order = EXCLUDED.sort_order, updated_at = now();

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
ON CONFLICT (category_id, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, updated_at = now();

INSERT INTO public.standard_unit_prices (model_id, width_mm, height_mm, price)
SELECT m.id, w, h, 0
FROM public.standard_unit_price_models m
JOIN public.standard_unit_price_categories c ON c.id = m.category_id
CROSS JOIN generate_series(2000, 8000, 1000) AS w
CROSS JOIN generate_series(2000, 8000, 1000) AS h
WHERE c.name IN ('스피드도어', '차고문')
ON CONFLICT (model_id, width_mm, height_mm) DO NOTHING;
