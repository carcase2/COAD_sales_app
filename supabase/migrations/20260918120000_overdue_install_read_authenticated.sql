-- 발급요청 대안 경로: 예정일 지난 현장 목록이 inquiries / 수금 캐시를 읽는다.
-- 테이블은 COAD_MES가 관리하므로 있을 때만 SELECT 정책을 연다.

DO $$
BEGIN
  IF to_regclass('public.inquiries') IS NOT NULL THEN
    ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS inquiries_select_authenticated ON public.inquiries;
    CREATE POLICY inquiries_select_authenticated
      ON public.inquiries
      FOR SELECT
      TO anon, authenticated
      USING (true);
    EXECUTE 'GRANT SELECT ON public.inquiries TO anon, authenticated';
  END IF;

  IF to_regclass('public.mes_unpaid_receivables') IS NOT NULL THEN
    ALTER TABLE public.mes_unpaid_receivables ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS mes_unpaid_receivables_select_authenticated
      ON public.mes_unpaid_receivables;
    CREATE POLICY mes_unpaid_receivables_select_authenticated
      ON public.mes_unpaid_receivables
      FOR SELECT
      TO anon, authenticated
      USING (true);
    EXECUTE 'GRANT SELECT ON public.mes_unpaid_receivables TO anon, authenticated';
  END IF;

  IF to_regclass('public.mes_inquiries') IS NOT NULL THEN
    ALTER TABLE public.mes_inquiries ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS mes_inquiries_select_authenticated ON public.mes_inquiries;
    CREATE POLICY mes_inquiries_select_authenticated
      ON public.mes_inquiries
      FOR SELECT
      TO anon, authenticated
      USING (true);
    EXECUTE 'GRANT SELECT ON public.mes_inquiries TO anon, authenticated';
  END IF;
END $$;
