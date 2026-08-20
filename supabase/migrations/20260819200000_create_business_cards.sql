-- 명함 수첩: 등록·검색·작성자·공개범위·댓글
-- 로그인 은 커스텀 users 테이블(anon 키)이라 auth.uid() RLS 는 쓸 수 없다.
-- 비공개 카드는 앱에서 created_by / admin 으로 거르고, 수정은 작성자·관리자만.

CREATE TABLE IF NOT EXISTS public.business_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT '',
  company text NOT NULL DEFAULT '',
  title text NOT NULL DEFAULT '',
  mobile_phone text NOT NULL DEFAULT '',
  office_phone text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  address text NOT NULL DEFAULT '',
  memo text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  visibility text NOT NULL DEFAULT 'team'
    CHECK (visibility IN ('team', 'private')),
  created_by text NOT NULL,
  created_by_name text NOT NULL DEFAULT '',
  updated_by text NOT NULL DEFAULT '',
  updated_by_name text NOT NULL DEFAULT '',
  search_text text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.business_card_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id uuid NOT NULL REFERENCES public.business_cards(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_by text NOT NULL,
  created_by_name text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE INDEX IF NOT EXISTS business_cards_updated_idx
  ON public.business_cards (deleted_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS business_cards_created_by_idx
  ON public.business_cards (created_by, deleted_at);
CREATE INDEX IF NOT EXISTS business_cards_visibility_idx
  ON public.business_cards (visibility, deleted_at);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS business_cards_search_idx
  ON public.business_cards USING gin (search_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS business_card_comments_card_idx
  ON public.business_card_comments (card_id, created_at)
  WHERE deleted_at IS NULL;

COMMENT ON TABLE public.business_cards IS '영업 명함 수첩. visibility=team 은 로그인 사용자 공유, private 은 작성자·관리자만.';
COMMENT ON TABLE public.business_card_comments IS '명함 댓글. 작성자만 수정, 작성자·관리자 삭제.';

CREATE OR REPLACE FUNCTION public.business_cards_touch_search()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_text := lower(concat_ws(
    ' ',
    NEW.name,
    NEW.company,
    NEW.title,
    NEW.mobile_phone,
    regexp_replace(coalesce(NEW.mobile_phone, ''), '[^0-9]', '', 'g'),
    NEW.office_phone,
    regexp_replace(coalesce(NEW.office_phone, ''), '[^0-9]', '', 'g'),
    NEW.email,
    NEW.address,
    NEW.memo,
    NEW.created_by_name
  ));
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS business_cards_touch_search ON public.business_cards;
CREATE TRIGGER business_cards_touch_search
  BEFORE INSERT OR UPDATE ON public.business_cards
  FOR EACH ROW
  EXECUTE FUNCTION public.business_cards_touch_search();

CREATE OR REPLACE FUNCTION public.business_card_comments_touch()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS business_card_comments_touch ON public.business_card_comments;
CREATE TRIGGER business_card_comments_touch
  BEFORE UPDATE ON public.business_card_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.business_card_comments_touch();

ALTER TABLE public.business_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_card_comments ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'business_cards' AND policyname = 'business_cards_all'
  ) THEN
    CREATE POLICY business_cards_all ON public.business_cards
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'business_card_comments'
      AND policyname = 'business_card_comments_all'
  ) THEN
    CREATE POLICY business_card_comments_all ON public.business_card_comments
      FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
