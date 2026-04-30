-- Performance indexes for frequently filtered/sorted read paths.
-- Guarded with to_regclass so this migration stays safe across environments
-- where some legacy tables may not exist yet.

do $$
begin
  if to_regclass('public.sales_calls') is not null then
    execute 'create index if not exists sales_calls_call_date_idx
      on public.sales_calls (call_date)';
    execute 'create index if not exists sales_calls_next_scheduled_date_idx
      on public.sales_calls (next_scheduled_date)';
    execute 'create index if not exists sales_calls_status_id_idx
      on public.sales_calls (status_id)';
    execute 'create index if not exists sales_calls_created_at_desc_idx
      on public.sales_calls (created_at desc)';
    execute 'create index if not exists sales_calls_call_date_created_at_desc_idx
      on public.sales_calls (call_date, created_at desc)';
  end if;

  if to_regclass('public.tax_invoice_issues') is not null then
    execute 'create index if not exists tax_invoice_issues_tax_invoice_id_idx
      on public.tax_invoice_issues (tax_invoice_id)';
    execute 'create index if not exists tax_invoice_issues_created_at_desc_idx
      on public.tax_invoice_issues (created_at desc)';
  end if;

  if to_regclass('public.performance_bond_issues') is not null then
    execute 'create index if not exists performance_bond_issues_performance_bond_id_idx
      on public.performance_bond_issues (performance_bond_id)';
    execute 'create index if not exists performance_bond_issues_created_at_desc_idx
      on public.performance_bond_issues (created_at desc)';
  end if;
end
$$;
