-- 시공 사진(시공후) 검색·열람·저장 기록. 앱에서 fire-and-forget RPC.

create table if not exists public.install_after_search_logs (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  user_name text,
  action text not null default 'search',
  model_code text,
  model_label text,
  query text,
  result_count integer,
  site_name text,
  created_at timestamptz not null default now()
);

comment on table public.install_after_search_logs is
  '시공 사진 검색 기록 (search/view/download/open). 관리자 화면에서 기간별 조회.';

create index if not exists install_after_search_logs_created_at_idx
  on public.install_after_search_logs (created_at desc);

create index if not exists install_after_search_logs_user_id_idx
  on public.install_after_search_logs (user_id, created_at desc);

create index if not exists install_after_search_logs_action_idx
  on public.install_after_search_logs (action, created_at desc);

create or replace function public.record_install_after_search(
  p_user_id text,
  p_user_name text,
  p_action text,
  p_model_code text default null,
  p_model_label text default null,
  p_query text default null,
  p_result_count integer default null,
  p_site_name text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
begin
  if p_user_id is null or trim(p_user_id) = '' then
    return;
  end if;

  v_action := lower(trim(coalesce(p_action, 'search')));
  if v_action not in ('search', 'view', 'download', 'open') then
    v_action := 'search';
  end if;

  insert into public.install_after_search_logs (
    user_id,
    user_name,
    action,
    model_code,
    model_label,
    query,
    result_count,
    site_name
  ) values (
    trim(p_user_id),
    nullif(left(trim(coalesce(p_user_name, '')), 80), ''),
    v_action,
    nullif(left(trim(coalesce(p_model_code, '')), 40), ''),
    nullif(left(trim(coalesce(p_model_label, '')), 80), ''),
    nullif(left(trim(coalesce(p_query, '')), 120), ''),
    p_result_count,
    nullif(left(trim(coalesce(p_site_name, '')), 120), '')
  );
end;
$$;

grant execute on function public.record_install_after_search(
  text, text, text, text, text, text, integer, text
) to anon, authenticated;

alter table public.install_after_search_logs enable row level security;

drop policy if exists install_after_search_logs_select on public.install_after_search_logs;
create policy install_after_search_logs_select
on public.install_after_search_logs
for select
to anon, authenticated
using (true);
