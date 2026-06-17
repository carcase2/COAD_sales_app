-- 발급요청 INSERT 시 FCM Edge Function 호출 (웹·앱 공통)
-- 앱만 켜져 있을 때 감시하는 방식은 누락되므로 DB 트리거로 보강한다.

create extension if not exists pg_net with schema extensions;

create table if not exists public.issuance_push_dedup (
  dedupe_key text primary key,
  sent_at timestamptz not null default now()
);

create index if not exists issuance_push_dedup_sent_at_idx
  on public.issuance_push_dedup (sent_at);

alter table public.issuance_push_dedup enable row level security;

create or replace function public.trg_notify_issuance_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  should_notify boolean := false;
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  if TG_OP <> 'INSERT' then
    return NEW;
  end if;

  if TG_TABLE_NAME = 'tax_invoices' then
    should_notify := lower(coalesce(NEW.status, '')) = 'pending';
  elsif TG_TABLE_NAME = 'performance_bonds' then
    should_notify := lower(coalesce(NEW.status, '')) in ('pending', 'draft');
  elsif TG_TABLE_NAME = 'tax_invoice_issues' then
    should_notify := NEW.invoice_image_url is null;
  elsif TG_TABLE_NAME = 'performance_bond_issues' then
    should_notify := NEW.bond_image_url is null;
  end if;

  if should_notify then
    perform net.http_post(
      url := project_url || '/functions/v1/notify-issuance-request',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := jsonb_build_object(
        'type', 'INSERT',
        'table', TG_TABLE_NAME,
        'record', to_jsonb(NEW)
      )
    );
  end if;

  return NEW;
exception
  when others then
    raise warning 'trg_notify_issuance_request failed on %: %', TG_TABLE_NAME, SQLERRM;
    return NEW;
end;
$$;

drop trigger if exists trg_tax_invoices_notify_issuance_request on public.tax_invoices;
create trigger trg_tax_invoices_notify_issuance_request
  after insert on public.tax_invoices
  for each row
  execute function public.trg_notify_issuance_request();

drop trigger if exists trg_performance_bonds_notify_issuance_request on public.performance_bonds;
create trigger trg_performance_bonds_notify_issuance_request
  after insert on public.performance_bonds
  for each row
  execute function public.trg_notify_issuance_request();

drop trigger if exists trg_tax_invoice_issues_notify_issuance_request on public.tax_invoice_issues;
create trigger trg_tax_invoice_issues_notify_issuance_request
  after insert on public.tax_invoice_issues
  for each row
  execute function public.trg_notify_issuance_request();

drop trigger if exists trg_performance_bond_issues_notify_issuance_request on public.performance_bond_issues;
create trigger trg_performance_bond_issues_notify_issuance_request
  after insert on public.performance_bond_issues
  for each row
  execute function public.trg_notify_issuance_request();
