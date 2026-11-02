create schema if not exists purchase;
create table if not exists purchase.desktop_purchase_requests (
  id bigint generated always as identity primary key,
  requested_at timestamptz not null default now(),
  requester text,
  department text,
  purpose text,
  quantity int default 1,
  budget_krw bigint,
  requirements text,
  raw_request text not null,
  status text not null default 'open',
  chosen_rec_id bigint,
  purchased_at date,
  purchase_price_krw bigint,
  vendor text,
  notes text
);
create table if not exists purchase.desktop_purchase_recs (
  id bigint generated always as identity primary key,
  request_id bigint references purchase.desktop_purchase_requests(id) on delete cascade,
  created_at timestamptz not null default now(),
  rank int,
  title text not null,
  cpu text,
  gpu text,
  ram_gb int,
  storage text,
  os text,
  price_krw bigint,
  source_site text,
  source_url text,
  price_checked_at timestamptz,
  reason text
);
alter table purchase.desktop_purchase_requests enable row level security;
alter table purchase.desktop_purchase_recs enable row level security;
create index if not exists desktop_purchase_requests_text_idx on purchase.desktop_purchase_requests using gin (to_tsvector('simple', coalesce(purpose,'')||' '||coalesce(requirements,'')||' '||raw_request));
