alter table public.estimate_documents
  add column if not exists width_mm integer not null default 0,
  add column if not exists height_mm integer not null default 0,
  add column if not exists quantity integer not null default 1;
