-- Separate table for Settings > 업데이트 내역
-- Keep app_update_policy only for force/recommended update policy.

create table if not exists public.app_update_history (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  proposer text,
  release_notes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  is_visible boolean not null default true
);

create index if not exists app_update_history_created_at_desc_idx
  on public.app_update_history (created_at desc);

create index if not exists app_update_history_visible_created_at_desc_idx
  on public.app_update_history (is_visible, created_at desc);

alter table public.app_update_history enable row level security;

drop policy if exists app_update_history_read_authenticated on public.app_update_history;
create policy app_update_history_read_authenticated
on public.app_update_history
for select
to authenticated
using (is_visible = true);

comment on table public.app_update_history
  is '설정 화면의 업데이트 내역 표시 전용 테이블';

comment on column public.app_update_history.release_notes
  is 'JSON 배열 문자열 목록. 예) ["개선1","개선2"]';
