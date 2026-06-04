-- 앱에서 app_update_policy 조회(업데이트 배지·배너) 허용

alter table public.app_update_policy enable row level security;

drop policy if exists app_update_policy_read_authenticated on public.app_update_policy;
create policy app_update_policy_read_authenticated
on public.app_update_policy
for select
to authenticated
using (is_active = true);
