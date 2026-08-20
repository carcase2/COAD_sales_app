ALTER TABLE public.business_cards
  ADD COLUMN IF NOT EXISTS fax_phone text NOT NULL DEFAULT '';

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
    NEW.created_by_name
  ));
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
