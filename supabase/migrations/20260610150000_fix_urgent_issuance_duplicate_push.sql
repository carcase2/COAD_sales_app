-- 긴급 세금계산서: tax_invoices + tax_invoice_issues 동시 INSERT 시 푸시 2회 방지
-- tax_invoices는 트랜잭션 종료 시점(DEFERRED)에 pending issue 유무를 확인 후 1회만 발송.

create or replace function public.trg_notify_tax_invoice_deferred()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  if lower(coalesce(NEW.status, '')) <> 'pending' then
    return null;
  end if;

  -- 긴급·부분 등 issue 행이 있으면 tax_invoice_issues 트리거에서 알림
  if exists (
    select 1
    from public.tax_invoice_issues
    where tax_invoice_id = NEW.id
      and invoice_image_url is null
  ) then
    return null;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-issuance-request',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'tax_invoices',
      'record', to_jsonb(NEW)
    )
  );

  return null;
exception
  when others then
    raise warning 'trg_notify_tax_invoice_deferred failed: %', SQLERRM;
    return null;
end;
$$;

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

  -- tax_invoices는 DEFERRED 트리거(trg_notify_tax_invoice_deferred)에서 처리
  if TG_TABLE_NAME = 'performance_bonds' then
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
drop trigger if exists trg_tax_invoices_notify_issuance_request_deferred on public.tax_invoices;

create constraint trigger trg_tax_invoices_notify_issuance_request_deferred
  after insert on public.tax_invoices
  deferrable initially deferred
  for each row
  execute function public.trg_notify_tax_invoice_deferred();
