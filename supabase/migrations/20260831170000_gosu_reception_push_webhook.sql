-- 자동문의고수 접수 INSERT 시 FCM (웹·앱·AppSheet 공통).
-- 앱 invoke만 있으면 웹 접수는 알림이 빠진다.

create extension if not exists pg_net with schema extensions;

create table if not exists public.gosu_reception_push_dedup (
  id text primary key,
  sent_at timestamptz not null default now()
);

alter table public.gosu_reception_push_dedup enable row level security;

create or replace function public.trg_notify_gosu_reception()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  if TG_OP <> 'INSERT' then
    return NEW;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-gosu-reception',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', TG_TABLE_NAME,
      'record', to_jsonb(NEW)
    )
  );

  return NEW;
exception
  when others then
    raise warning 'trg_notify_gosu_reception failed: %', SQLERRM;
    return NEW;
end;
$$;

drop trigger if exists trg_gosu_sales_calls_notify_reception on public.gosu_sales_calls;
create trigger trg_gosu_sales_calls_notify_reception
  after insert on public.gosu_sales_calls
  for each row
  execute function public.trg_notify_gosu_reception();
