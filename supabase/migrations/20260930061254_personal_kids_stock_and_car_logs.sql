create schema if not exists personal;
revoke all on schema personal from anon, authenticated;
create table if not exists personal.kids_stock_log (
  id bigint generated always as identity primary key,
  date date not null,
  child text not null,
  ticker text not null,
  shares numeric,
  value_krw bigint,
  pnl_krw bigint,
  pnl_pct numeric,
  created_at timestamptz default now(),
  unique (date, child, ticker)
);
create table if not exists personal.car_drive_log (
  month text primary key,
  car text default 'Tesla Model Y RWD (pre-Juniper, KR)',
  odometer_km numeric,
  month_km numeric,
  wh_per_km numeric,
  energy_kwh numeric,
  drive_time text,
  range100_km numeric,
  note text,
  created_at timestamptz default now()
);
alter table personal.kids_stock_log enable row level security;
alter table personal.car_drive_log enable row level security;
revoke all on all tables in schema personal from anon, authenticated;
comment on schema personal is '경덕이 개인 기록(아이들 주식, 차 주행). 회사 데이터와 분리.';;
