-- 1단계: 서버에서 비밀번호 해시를 비교하는 로그인 RPC (아직 적용 안 함, 승인 후 supabase/migrations 로 옮겨 적용)
--
-- 바뀌는 것
--   * public.user_credentials: bcrypt 해시만 보관. RLS 켜고 정책 없음, anon/authenticated 권한 없음.
--     → anon 키로는 읽을 수도 쓸 수도 없다. security definer 함수만 접근.
--   * users.password 가 바뀌면(관리자 초기화, 웹 비밀번호 변경, 신규 등록) 트리거가 해시를 같이 갱신.
--     → COAD_home·New_MES 가 지금처럼 평문을 써도 해시가 어긋나지 않는다.
--   * public.app_login(p_id, p_password): 해시 비교 후 비밀번호를 뺀 사용자 JSON 반환, 실패 시 null.
--     같은 아이디로 15분 안에 10번 틀리면 15분 동안 거절.
--
-- 바뀌지 않는 것 (2단계에서 처리)
--   * users.password 평문 컬럼과 anon 읽기/쓰기 권한은 그대로다. 다른 앱이 아직 평문 비교를 쓰기 때문.
--   * 이 마이그레이션만으로는 노출이 줄지 않는다. 앱들이 모두 app_login 으로 옮긴 뒤 2단계를 적용해야 효과가 있다.

create table if not exists public.user_credentials (
  user_id text primary key references public.users(id) on delete cascade on update cascade,
  password_hash text not null,
  failed_count integer not null default 0,
  last_failed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_credentials enable row level security;
alter table public.user_credentials force row level security;
revoke all on table public.user_credentials from public, anon, authenticated;

-- users.password 가 바뀌면 해시를 맞춘다.
create or replace function public.sync_user_credentials()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if tg_op = 'UPDATE' and new.password is not distinct from old.password then
    return new;
  end if;

  if new.password is null or new.password = '' then
    delete from public.user_credentials where user_id = new.id;
  else
    insert into public.user_credentials (user_id, password_hash)
    values (new.id, extensions.crypt(new.password, extensions.gen_salt('bf', 10)))
    on conflict (user_id) do update
      set password_hash = excluded.password_hash,
          failed_count = 0,
          last_failed_at = null,
          updated_at = now();
  end if;
  return new;
end;
$$;

revoke all on function public.sync_user_credentials() from public, anon, authenticated;

drop trigger if exists trg_users_sync_credentials on public.users;
create trigger trg_users_sync_credentials
  after insert or update of password on public.users
  for each row execute function public.sync_user_credentials();

-- 기존 계정 해시 채우기 (81행, bcrypt cost 10 → 수 초)
insert into public.user_credentials (user_id, password_hash)
select u.id, extensions.crypt(u.password, extensions.gen_salt('bf', 10))
from public.users u
where coalesce(u.password, '') <> ''
on conflict (user_id) do nothing;

create or replace function public.app_login(p_id text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  u public.users;
  c public.user_credentials;
  ok boolean := false;
begin
  if coalesce(p_id, '') = '' or coalesce(p_password, '') = '' then
    return null;
  end if;

  select * into u from public.users where id = p_id;
  if not found then
    -- 없는 아이디도 해시 한 번만큼 시간을 쓴다 (아이디 존재 여부를 응답 시간으로 알기 어렵게)
    perform extensions.crypt(p_password, extensions.gen_salt('bf', 10));
    return null;
  end if;

  select * into c from public.user_credentials where user_id = u.id for update;

  if found then
    if c.failed_count >= 10 and c.last_failed_at > now() - interval '15 minutes' then
      return null;
    end if;
    ok := c.password_hash = extensions.crypt(p_password, c.password_hash);
    if ok then
      update public.user_credentials
        set failed_count = 0, last_failed_at = null
        where user_id = u.id and failed_count <> 0;
    else
      update public.user_credentials
        set failed_count = case when last_failed_at > now() - interval '15 minutes'
                                then failed_count + 1 else 1 end,
            last_failed_at = now()
        where user_id = u.id;
    end if;
  elsif coalesce(u.password, '') <> '' then
    -- 해시가 아직 없는 계정(트리거 전에 만든 행 등): 평문으로 한 번 확인하고 해시를 만든다.
    ok := u.password = p_password;
    if ok then
      insert into public.user_credentials (user_id, password_hash)
      values (u.id, extensions.crypt(p_password, extensions.gen_salt('bf', 10)))
      on conflict (user_id) do nothing;
    end if;
  end if;

  if not ok then
    return null;
  end if;

  return (to_jsonb(u) - 'password' - 'fcm_token')
    || jsonb_build_object(
         'groups', (select jsonb_build_object('name', g.name, 'permissions', g.permissions)
                    from public.groups g where g.id = u.group_id),
         'coad_branch', (select jsonb_build_object('name', b.name)
                         from public.coad_branch b where b.id = u.branch_id)
       );
end;
$$;

revoke all on function public.app_login(text, text) from public;
grant execute on function public.app_login(text, text) to anon, authenticated;

comment on function public.app_login(text, text) is
  '아이디·비밀번호를 서버에서 bcrypt 로 비교. 성공 시 password 를 뺀 users 행 + groups/coad_branch, 실패 시 null.';
