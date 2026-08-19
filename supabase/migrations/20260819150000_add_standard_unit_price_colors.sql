ALTER TABLE public.standard_unit_price_categories
  ADD COLUMN IF NOT EXISTS color text NOT NULL DEFAULT '#334155';

ALTER TABLE public.standard_unit_price_models
  ADD COLUMN IF NOT EXISTS color text NOT NULL DEFAULT '#334155';

UPDATE public.standard_unit_price_categories SET color = '#059669', updated_at = now() WHERE name = '스피드도어';
UPDATE public.standard_unit_price_categories SET color = '#d97706', updated_at = now() WHERE name = '차고문';

UPDATE public.standard_unit_price_models m
SET color = v.color, updated_at = now()
FROM public.standard_unit_price_categories c,
(
  VALUES
    ('스피드도어', 'VE STANDARD', '#0d9488'),
    ('스피드도어', 'STANDARD', '#2563eb'),
    ('스피드도어', 'DELUEX', '#7c3aed'),
    ('스피드도어', 'PREMIUM', '#db2777'),
    ('차고문', 'STANDARD(우드판넬)', '#c2410c'),
    ('차고문', 'DELUEX(다크 그레이,브라운)', '#44403c'),
    ('차고문', 'PREMIUM(샤틴펄)', '#0284c7'),
    ('차고문', 'PREMIUM(마블스톤)', '#78716c')
) AS v(category_name, model_name, color)
WHERE m.category_id = c.id
  AND c.name = v.category_name
  AND m.name = v.model_name;
