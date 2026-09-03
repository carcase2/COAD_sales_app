-- A/S 방문 팀(본사·지사별) + call_logs.visit_team_id (A/S DB에 call_logs가 있을 때만)

CREATE TABLE IF NOT EXISTS public.support_as_visit_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch text NOT NULL,
  name text NOT NULL DEFAULT '',
  members text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT support_as_visit_teams_branch_check
    CHECK (branch IN ('본사', '대구', '대전', '전남', '기타'))
);

CREATE INDEX IF NOT EXISTS support_as_visit_teams_branch_idx
  ON public.support_as_visit_teams (branch, active, sort_order);

COMMENT ON TABLE public.support_as_visit_teams IS
  '고객지원 A/S 방문 팀. 본사·지사별 팀 이름·팀원. 하루 1팀 1건.';

ALTER TABLE public.support_as_visit_teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS support_as_visit_teams_all ON public.support_as_visit_teams;
CREATE POLICY support_as_visit_teams_all
  ON public.support_as_visit_teams
  FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.support_as_visit_teams
  TO anon, authenticated;

INSERT INTO public.support_as_visit_teams (id, branch, name, members, sort_order)
VALUES
  ('a1000000-0000-4000-8000-000000000001', '본사', '1팀', '', 0),
  ('a1000000-0000-4000-8000-000000000002', '본사', '2팀', '', 1),
  ('a1000000-0000-4000-8000-000000000011', '대구', '1팀', '', 0),
  ('a1000000-0000-4000-8000-000000000021', '대전', '1팀', '', 0),
  ('a1000000-0000-4000-8000-000000000031', '전남', '1팀', '', 0),
  ('a1000000-0000-4000-8000-000000000041', '기타', '1팀', '', 0)
ON CONFLICT (id) DO NOTHING;

-- call_logs는 A/S(Support) Supabase에만 있음. 메인 프로젝트에 없으면 건너뛴다.
DO $$
BEGIN
  IF to_regclass('public.call_logs') IS NOT NULL THEN
    ALTER TABLE public.call_logs
      ADD COLUMN IF NOT EXISTS visit_team_id uuid
        REFERENCES public.support_as_visit_teams(id) ON DELETE SET NULL;

    CREATE INDEX IF NOT EXISTS call_logs_visit_team_date_idx
      ON public.call_logs (visit_date, visit_team_id)
      WHERE visit_date IS NOT NULL;

    COMMENT ON COLUMN public.call_logs.visit_team_id IS
      'A/S 방문 배정 팀. support_as_visit_teams.id';
  END IF;
END $$;
