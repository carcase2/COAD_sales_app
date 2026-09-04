-- 같은 팀·날짜·시간에 방문 두 건이 들어가지 않게. A/S DB에 call_logs가 있을 때만.
DO $$
BEGIN
  IF to_regclass('public.call_logs') IS NOT NULL THEN
    CREATE UNIQUE INDEX IF NOT EXISTS call_logs_visit_slot_uidx
      ON public.call_logs (visit_date, visit_team_id, visit_time)
      WHERE visit_date IS NOT NULL
        AND visit_team_id IS NOT NULL
        AND visit_time IS NOT NULL
        AND (service_status_id IS DISTINCT FROM 1);
  END IF;
END $$;
