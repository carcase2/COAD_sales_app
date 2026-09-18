-- 수금 상세에서 R2 아카이브(시공후·계약완료보고서)를 읽는다.

DO $$
BEGIN
  IF to_regclass('public.archive_attachments') IS NOT NULL THEN
    ALTER TABLE public.archive_attachments ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS archive_attachments_select_authenticated
      ON public.archive_attachments;
    CREATE POLICY archive_attachments_select_authenticated
      ON public.archive_attachments
      FOR SELECT
      TO anon, authenticated
      USING (true);
    EXECUTE 'GRANT SELECT ON public.archive_attachments TO anon, authenticated';
  END IF;
END $$;
