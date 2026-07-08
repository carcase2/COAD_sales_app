-- 일별 앱 사용량 집계 (관리자 조회용)
create table if not exists public.app_usage_daily (
  user_id text not null,
  user_name text,
  usage_date date not null,
  app_opens integer not null default 0,
  tab_counts jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, usage_date)
);

create index if not exists app_usage_daily_usage_date_idx
  on public.app_usage_daily (usage_date desc);

create index if not exists app_usage_daily_updated_at_idx
  on public.app_usage_daily (updated_at desc);

-- 앱에서 fire-and-forget 호출 — 날짜별 집계를 원자적으로 갱신
create or replace function public.record_app_usage(
  p_user_id text,
  p_user_name text,
  p_usage_date date,
  p_kind text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or trim(p_user_id) = '' then
    return;
  end if;

  insert into public.app_usage_daily (
    user_id,
    user_name,
    usage_date,
    app_opens,
    tab_counts
  ) values (
    p_user_id,
    p_user_name,
    p_usage_date,
    case when p_kind = 'app_open' then 1 else 0 end,
    case
      when p_kind = 'app_open' then '{}'::jsonb
      else jsonb_build_object(p_kind, 1)
    end
  )
  on conflict (user_id, usage_date) do update set
    user_name = excluded.user_name,
    app_opens = app_usage_daily.app_opens
      + case when p_kind = 'app_open' then 1 else 0 end,
    tab_counts = case
      when p_kind = 'app_open' then app_usage_daily.tab_counts
      else jsonb_set(
        app_usage_daily.tab_counts,
        array[p_kind],
        to_jsonb(coalesce((app_usage_daily.tab_counts ->> p_kind)::int, 0) + 1),
        true
      )
    end,
    updated_at = now();
end;
$$;

grant execute on function public.record_app_usage(text, text, date, text)
  to anon, authenticated;

alter table public.app_usage_daily enable row level security;

drop policy if exists app_usage_daily_read_anon on public.app_usage_daily;
create policy app_usage_daily_read_anon
on public.app_usage_daily
for select
to anon, authenticated
using (true);
