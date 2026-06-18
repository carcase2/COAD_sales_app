-- user_groups는 이 DB에서 junction 테이블이 아님 — users.group_id + groups 로 총무부 확인.

create or replace function public.cancel_performance_bond(
  p_bond_id uuid,
  p_user_name text,
  p_cancel_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user record;
  v_bond record;
  v_is_general_affairs boolean := false;
begin
  if p_bond_id is null then
    raise exception '이행증권 ID가 필요합니다.';
  end if;
  if coalesce(trim(p_user_name), '') = '' then
    raise exception '요청 사용자 정보가 없습니다.';
  end if;
  if coalesce(trim(p_cancel_reason), '') = '' then
    raise exception '취소 사유를 입력해 주세요.';
  end if;

  select id, name, role, group_id
    into v_user
    from users
   where name = trim(p_user_name)
   limit 1;

  if not found then
    raise exception '사용자를 찾을 수 없습니다: %', trim(p_user_name);
  end if;

  select *
    into v_bond
    from performance_bonds
   where id = p_bond_id
   limit 1;

  if not found then
    raise exception '이행증권을 찾을 수 없습니다.';
  end if;

  if v_bond.status in ('in_progress', 'completed', 'issued') then
    raise exception '발급완료된 이행증권은 취소할 수 없습니다.';
  end if;

  if v_user.group_id is not null then
    select exists (
      select 1
        from groups g
       where g.id = v_user.group_id
         and g.name = '총무부'
    )
      into v_is_general_affairs;
  end if;

  if v_bond.created_by is distinct from v_user.name
     and v_user.role is distinct from 'admin'
     and not v_is_general_affairs then
    raise exception '취소 권한이 없습니다. 관리자/총무부/작성자만 취소할 수 있습니다.';
  end if;

  update performance_bonds
     set status = 'cancelled',
         cancel_reason = trim(p_cancel_reason),
         cancelled_by = trim(p_user_name),
         cancelled_at = timezone('utc', now()),
         updated_by = trim(p_user_name)
   where id = p_bond_id;
end;
$$;

grant execute on function public.cancel_performance_bond(uuid, text, text) to anon, authenticated;
