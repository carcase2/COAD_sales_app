-- 사이즈 표준단가에서 바로 작성하는 영업 견적서.
-- 견적서 연동은 후속이었던 표준단가 테이블의 다음 단계.

CREATE TABLE IF NOT EXISTS public.standard_unit_price_quotes (
  id text PRIMARY KEY,
  quote_no text NOT NULL DEFAULT '',
  ymd date,
  customer_name text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  site text NOT NULL DEFAULT '',
  address text NOT NULL DEFAULT '',
  work_name text NOT NULL DEFAULT '',
  category_id text,
  category_name text NOT NULL DEFAULT '',
  model_id text,
  model_name text NOT NULL DEFAULT '',
  width_mm integer NOT NULL DEFAULT 0,
  height_mm integer NOT NULL DEFAULT 0,
  quantity integer NOT NULL DEFAULT 1,
  standard_price integer NOT NULL DEFAULT 0,
  markup_type text NOT NULL DEFAULT 'none',
  markup_value numeric NOT NULL DEFAULT 0,
  lines jsonb NOT NULL DEFAULT '[]'::jsonb,
  promo_image_ids jsonb NOT NULL DEFAULT '[]'::jsonb,
  note text NOT NULL DEFAULT '',
  total integer NOT NULL DEFAULT 0,
  nego_amount integer NOT NULL DEFAULT 0,
  nego_percent numeric NOT NULL DEFAULT 0,
  target_total integer,
  sent_ymd date,
  email_sent_ymd date,
  created_by text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_by text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  edit_history jsonb NOT NULL DEFAULT '[]'::jsonb,
  pdf_path text NOT NULL DEFAULT '',
  pdf_uploaded_at timestamptz,
  pdf_uploaded_by text NOT NULL DEFAULT '',
  search_text text NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS standard_unit_price_quotes_ymd_idx
  ON public.standard_unit_price_quotes (ymd DESC NULLS LAST, created_at DESC);
CREATE INDEX IF NOT EXISTS standard_unit_price_quotes_site_idx
  ON public.standard_unit_price_quotes (site);
CREATE INDEX IF NOT EXISTS standard_unit_price_quotes_model_size_idx
  ON public.standard_unit_price_quotes (model_id, width_mm, height_mm);
CREATE INDEX IF NOT EXISTS standard_unit_price_quotes_quote_no_idx
  ON public.standard_unit_price_quotes (quote_no);

ALTER TABLE public.standard_unit_price_quotes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS standard_unit_price_quotes_all
  ON public.standard_unit_price_quotes;
CREATE POLICY standard_unit_price_quotes_all
  ON public.standard_unit_price_quotes
  FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.standard_unit_price_quotes TO anon, authenticated;

COMMENT ON TABLE public.standard_unit_price_quotes IS
  '사이즈 표준단가 영업 견적서. 메인·부자재·기타, 마진, 네고, 목표금액, 홍보 이미지, PDF·메일 기록.';

CREATE TABLE IF NOT EXISTS public.standard_unit_price_promo_images (
  id text PRIMARY KEY,
  model_id text NOT NULL,
  title text NOT NULL DEFAULT '',
  storage_path text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_by text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS standard_unit_price_promo_images_model_idx
  ON public.standard_unit_price_promo_images (model_id, sort_order);

ALTER TABLE public.standard_unit_price_promo_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS standard_unit_price_promo_images_all
  ON public.standard_unit_price_promo_images;
CREATE POLICY standard_unit_price_promo_images_all
  ON public.standard_unit_price_promo_images
  FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.standard_unit_price_promo_images TO anon, authenticated;

COMMENT ON TABLE public.standard_unit_price_promo_images IS
  '모델별 견적서 다음장 홍보 이미지.';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'standard-unit-price-quotes',
  'standard-unit-price-quotes',
  true,
  20971520,
  ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'standard-unit-price-promo',
  'standard-unit-price-promo',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS standard_unit_price_quotes_storage_all ON storage.objects;
CREATE POLICY standard_unit_price_quotes_storage_all
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'standard-unit-price-quotes')
  WITH CHECK (bucket_id = 'standard-unit-price-quotes');

DROP POLICY IF EXISTS standard_unit_price_promo_storage_all ON storage.objects;
CREATE POLICY standard_unit_price_promo_storage_all
  ON storage.objects
  FOR ALL
  USING (bucket_id = 'standard-unit-price-promo')
  WITH CHECK (bucket_id = 'standard-unit-price-promo');
