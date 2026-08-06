-- 사용자별 다중 기기 FCM 토큰 저장
create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.users(id) on delete cascade,
  device_key text not null,
  platform text not null default 'unknown',
  fcm_token text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, device_key),
  unique (fcm_token)
);

create index if not exists idx_user_push_tokens_user_id
  on public.user_push_tokens(user_id);

create index if not exists idx_user_push_tokens_active
  on public.user_push_tokens(is_active);

create or replace function public.set_updated_at_user_push_tokens()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_push_tokens_updated_at on public.user_push_tokens;
create trigger trg_user_push_tokens_updated_at
before update on public.user_push_tokens
for each row
execute function public.set_updated_at_user_push_tokens();

alter table public.user_push_tokens disable row level security;
