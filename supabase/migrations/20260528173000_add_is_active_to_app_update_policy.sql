-- Ensure only one active update policy is used for app update checks.

alter table public.app_update_policy
  add column if not exists is_active boolean not null default true;

-- At most one active row allowed.
create unique index if not exists app_update_policy_one_active_idx
  on public.app_update_policy ((is_active))
  where is_active = true;

comment on column public.app_update_policy.is_active
  is '업데이트 체크 대상 정책 활성 여부. true는 반드시 1건만 유지.';
