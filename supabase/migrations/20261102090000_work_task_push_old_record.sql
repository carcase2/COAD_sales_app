-- 업무 상태 알림에 바뀌기 전 행(old_record)을 같이 보낸다.
-- notify-work-task 가 「보류 → 재개」, 「시작 후 n분 만에 완료」처럼 전이별 문구를 만든다.

create or replace function public.trg_notify_work_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
  kind text;
  payload jsonb;
begin
  if tg_op = 'INSERT' then
    kind := 'added';
    payload := jsonb_build_object('kind', kind, 'record', to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    if new.status_id is not distinct from old.status_id then
      return new;
    end if;
    kind := 'status';
    payload := jsonb_build_object(
      'kind', kind,
      'record', to_jsonb(new),
      'old_record', to_jsonb(old)
    );
  else
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-work-task',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := payload
  );
  return new;
exception
  when others then
    raise warning 'trg_notify_work_task failed: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.trg_notify_work_task() from public, anon, authenticated;
