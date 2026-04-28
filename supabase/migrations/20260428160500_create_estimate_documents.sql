create table if not exists public.estimate_documents (
  id text primary key,
  category text not null,
  model_name text not null,
  customer_name text not null,
  site_name text not null default '',
  width_mm integer not null default 0,
  height_mm integer not null default 0,
  quantity integer not null default 1,
  base_amount integer not null default 0,
  extra_items jsonb not null default '[]'::jsonb,
  custom_fields jsonb not null default '{}'::jsonb,
  memo text not null default '',
  search_text text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists estimate_documents_updated_at_idx
  on public.estimate_documents (updated_at desc);

create index if not exists estimate_documents_search_text_idx
  on public.estimate_documents using gin (to_tsvector('simple', coalesce(search_text, '')));

create or replace function public.set_estimate_documents_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_estimate_documents_updated_at on public.estimate_documents;
create trigger trg_estimate_documents_updated_at
before update on public.estimate_documents
for each row
execute function public.set_estimate_documents_updated_at();

alter table public.estimate_documents enable row level security;

drop policy if exists "estimate_documents_select_auth" on public.estimate_documents;
create policy "estimate_documents_select_auth"
on public.estimate_documents
for select
to authenticated
using (true);

drop policy if exists "estimate_documents_insert_auth" on public.estimate_documents;
create policy "estimate_documents_insert_auth"
on public.estimate_documents
for insert
to authenticated
with check (true);

drop policy if exists "estimate_documents_update_auth" on public.estimate_documents;
create policy "estimate_documents_update_auth"
on public.estimate_documents
for update
to authenticated
using (true)
with check (true);

drop policy if exists "estimate_documents_delete_auth" on public.estimate_documents;
create policy "estimate_documents_delete_auth"
on public.estimate_documents
for delete
to authenticated
using (true);
