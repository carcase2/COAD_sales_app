-- 발급 완료(이미지 업로드) 시 FCM — 웹 발급 처리 후 앱 푸시

create or replace function public.trg_notify_issuance_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
  became_issued boolean := false;
begin
  if TG_OP <> 'UPDATE' then
    return NEW;
  end if;

  if TG_TABLE_NAME = 'tax_invoice_issues' then
    became_issued := coalesce(OLD.invoice_image_url::text, '') = ''
      and coalesce(NEW.invoice_image_url::text, '') <> '';
  elsif TG_TABLE_NAME = 'performance_bond_issues' then
    became_issued := coalesce(OLD.bond_image_url::text, '') = ''
      and coalesce(NEW.bond_image_url::text, '') <> '';
  elsif TG_TABLE_NAME = 'tax_invoices' then
    became_issued := coalesce(OLD.invoice_image_url::text, '') = ''
      and coalesce(NEW.invoice_image_url::text, '') <> '';
  elsif TG_TABLE_NAME = 'performance_bonds' then
    became_issued := coalesce(OLD.bond_image_url::text, '') = ''
      and coalesce(NEW.bond_image_url::text, '') <> '';
  end if;

  if became_issued then
    perform net.http_post(
      url := project_url || '/functions/v1/notify-issuance-request',
      headers := jsonb_build_object('Content-Type', 'application/json'),
      body := jsonb_build_object(
        'type', 'UPDATE',
        'table', TG_TABLE_NAME,
        'record', to_jsonb(NEW),
        'old_record', to_jsonb(OLD)
      )
    );
  end if;

  return NEW;
exception
  when others then
    raise warning 'trg_notify_issuance_completed failed on %: %', TG_TABLE_NAME, SQLERRM;
    return NEW;
end;
$$;

drop trigger if exists trg_tax_invoice_issues_notify_issuance_completed on public.tax_invoice_issues;
create trigger trg_tax_invoice_issues_notify_issuance_completed
  after update on public.tax_invoice_issues
  for each row
  execute function public.trg_notify_issuance_completed();

drop trigger if exists trg_performance_bond_issues_notify_issuance_completed on public.performance_bond_issues;
create trigger trg_performance_bond_issues_notify_issuance_completed
  after update on public.performance_bond_issues
  for each row
  execute function public.trg_notify_issuance_completed();

drop trigger if exists trg_tax_invoices_notify_issuance_completed on public.tax_invoices;
create trigger trg_tax_invoices_notify_issuance_completed
  after update on public.tax_invoices
  for each row
  execute function public.trg_notify_issuance_completed();

drop trigger if exists trg_performance_bonds_notify_issuance_completed on public.performance_bonds;
create trigger trg_performance_bonds_notify_issuance_completed
  after update on public.performance_bonds
  for each row
  execute function public.trg_notify_issuance_completed();
