-- 고객지원팀 A/S 견적단가표. 사이즈 표준단가와 별개.
-- 추가·수정·삭제 가능. 삭제는 soft delete. 변경 이력은 별도 테이블에 남긴다.

CREATE TABLE IF NOT EXISTS public.support_as_unit_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  spec text NOT NULL DEFAULT '',
  price integer CHECK (price IS NULL OR price >= 0),
  note text NOT NULL DEFAULT '',
  sort_order int NOT NULL DEFAULT 0,
  created_by text NOT NULL DEFAULT '',
  created_by_name text NOT NULL DEFAULT '',
  updated_by text NOT NULL DEFAULT '',
  updated_by_name text NOT NULL DEFAULT '',
  deleted_at timestamptz,
  deleted_by text NOT NULL DEFAULT '',
  deleted_by_name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_as_unit_price_change_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id uuid REFERENCES public.support_as_unit_prices(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (action IN ('create', 'update', 'delete')),
  item_name text NOT NULL DEFAULT '',
  old_name text,
  old_spec text,
  old_price integer,
  old_note text,
  new_name text,
  new_spec text,
  new_price integer,
  new_note text,
  summary text NOT NULL DEFAULT '',
  user_id text NOT NULL DEFAULT '',
  user_name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_as_unit_prices_updated_idx
  ON public.support_as_unit_prices (deleted_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS support_as_unit_prices_name_idx
  ON public.support_as_unit_prices (name);
CREATE INDEX IF NOT EXISTS support_as_unit_price_change_logs_created_idx
  ON public.support_as_unit_price_change_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS support_as_unit_price_change_logs_item_idx
  ON public.support_as_unit_price_change_logs (item_id, created_at DESC);

COMMENT ON TABLE public.support_as_unit_prices IS '고객지원 A/S 견적단가. 접수·팔로우업 중 검색. 삭제는 deleted_at.';
COMMENT ON TABLE public.support_as_unit_price_change_logs IS 'A/S 단가 추가·수정·삭제 이력. 누가·어떻게 바꿨는지.';

ALTER TABLE public.support_as_unit_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_as_unit_price_change_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_as_unit_prices'
      AND policyname = 'support_as_unit_prices_all'
  ) THEN
    CREATE POLICY support_as_unit_prices_all
      ON public.support_as_unit_prices
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_as_unit_price_change_logs'
      AND policyname = 'support_as_unit_price_change_logs_select'
  ) THEN
    CREATE POLICY support_as_unit_price_change_logs_select
      ON public.support_as_unit_price_change_logs
      FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_as_unit_price_change_logs'
      AND policyname = 'support_as_unit_price_change_logs_insert'
  ) THEN
    CREATE POLICY support_as_unit_price_change_logs_insert
      ON public.support_as_unit_price_change_logs
      FOR INSERT WITH CHECK (true);
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_as_unit_prices TO anon, authenticated;
GRANT SELECT, INSERT ON public.support_as_unit_price_change_logs TO anon, authenticated;
