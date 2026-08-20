ALTER TABLE public.business_cards
  ADD COLUMN IF NOT EXISTS is_blacklisted boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS business_cards_blacklist_idx
  ON public.business_cards (is_blacklisted)
  WHERE deleted_at IS NULL AND is_blacklisted = true;

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
    NEW.fax_phone,
    regexp_replace(coalesce(NEW.fax_phone, ''), '[^0-9]', '', 'g'),
    NEW.email,
    NEW.address,
    NEW.memo,
    NEW.created_by_name,
    CASE WHEN NEW.is_blacklisted THEN '블랙리스트 블랙' ELSE '' END
  ));
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
