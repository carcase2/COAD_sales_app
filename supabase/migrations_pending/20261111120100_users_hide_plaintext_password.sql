-- 2단계: 평문 비밀번호 숨기기·지우기 (영업 앱·COAD_home·New_MES 가 모두 app_login 으로 바뀐 뒤에만 적용)
--
-- 적용 전 확인
--   * 영업 앱: 이 브랜치가 들어간 빌드가 강제 업데이트 기준 이상이어야 한다 (구버전은 users.password 를 직접 조회).
--   * COAD_home: validateUserWithSupabase / scheduleApi.login 이 app_login 사용,
--     users 를 select('*') 로 읽는 곳이 없어야 한다 (컬럼 권한을 빼면 * 조회는 permission denied).
--   * New_MES: src/lib/auth.ts 가 app_login 사용.
--
-- 이후 비밀번호 쓰기(관리자 초기화, 비밀번호 변경, 신규 등록)는 지금처럼 users.password 에 평문을 넣어도 된다.
-- 트리거가 해시만 남기고 평문은 지운다.

-- 1) anon/authenticated 가 password 컬럼을 못 읽게: 테이블 SELECT 를 빼고 나머지 컬럼만 허용.
--    (Postgres 에서는 테이블 단위 SELECT 가 있으면 컬럼 단위 revoke 가 효과 없음)
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
    into cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'users' and column_name <> 'password';

  execute 'revoke select on table public.users from anon, authenticated';
  execute format('grant select (%s) on table public.users to anon, authenticated', cols);
end $$;

-- 2) 새로 들어오는 평문은 해시만 남기고 비운다.
--    1단계의 AFTER 트리거를 UPDATE 는 BEFORE(같은 자리에서 평문 비움), INSERT 는 AFTER(FK 때문)로 나눈다.
drop trigger if exists trg_users_sync_credentials on public.users;

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
  if new.password is not null and new.password <> '' then
    insert into public.user_credentials (user_id, password_hash)
    values (new.id, extensions.crypt(new.password, extensions.gen_salt('bf', 10)))
    on conflict (user_id) do update
      set password_hash = excluded.password_hash,
          failed_count = 0,
          last_failed_at = null,
          updated_at = now();
    new.password := null;
  end if;
  return new;
end;
$$;

-- INSERT 는 users 행이 먼저 있어야 FK 를 만족하므로 AFTER, UPDATE 는 BEFORE 에서 평문을 비운다.
create trigger trg_users_sync_credentials_upd
  before update of password on public.users
  for each row execute function public.sync_user_credentials();

create or replace function public.sync_user_credentials_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new.password is not null and new.password <> '' then
    insert into public.user_credentials (user_id, password_hash)
    values (new.id, extensions.crypt(new.password, extensions.gen_salt('bf', 10)))
    on conflict (user_id) do update set password_hash = excluded.password_hash, updated_at = now();
    update public.users set password = null where id = new.id;
  end if;
  return null;
end;
$$;

create trigger trg_users_sync_credentials_ins
  after insert on public.users
  for each row execute function public.sync_user_credentials_after_insert();

-- 3) 기존 평문 지우기. 해시가 없는 행이 남아 있으면 중단.
do $$
begin
  if exists (
    select 1 from public.users u
    where coalesce(u.password, '') <> ''
      and not exists (select 1 from public.user_credentials c where c.user_id = u.id)
  ) then
    raise exception 'user_credentials 에 해시가 없는 계정이 있습니다. 1단계 백필을 다시 확인하세요.';
  end if;
end $$;

alter table public.users disable trigger trg_users_sync_credentials_upd;
update public.users set password = null where password is not null;
alter table public.users enable trigger trg_users_sync_credentials_upd;

-- 주의: '1234'/빈 비밀번호를 "초기 비밀번호" 로 보는 COAD_home 로직은 평문이 사라지면 동작하지 않는다.
-- 초기화가 필요하면 users.password 에 '1234' 를 쓰고(해시로 저장됨), 첫 로그인 후 변경 강제는
-- 별도 컬럼(예: users.needs_password_reset)으로 옮겨야 한다.
