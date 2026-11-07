-- 부서 요청(work_requests) 알림과 업무 댓글(task_comments) 알림.
-- 앱·연구소 웹·COAD_home 어디서 써도 DB 트리거가 같은 알림 함수를 부른다.

create or replace function public.trg_notify_work_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  if tg_op = 'UPDATE'
     and new.status is not distinct from old.status
     and new.progress is not distinct from old.progress then
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-work-request',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', tg_op,
      'record', to_jsonb(new),
      'old_record', case when tg_op = 'UPDATE' then to_jsonb(old) else '{}'::jsonb end
    )
  );
  return new;
exception
  when others then
    raise warning 'trg_notify_work_request failed: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.trg_notify_work_request() from public, anon, authenticated;

drop trigger if exists trg_work_requests_notify on public.work_requests;
create trigger trg_work_requests_notify
  after insert or update on public.work_requests
  for each row execute function public.trg_notify_work_request();

create or replace function public.trg_notify_work_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  perform net.http_post(
    url := project_url || '/functions/v1/notify-work-task',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object('kind', 'comment', 'record', to_jsonb(new))
  );
  return new;
exception
  when others then
    raise warning 'trg_notify_work_comment failed: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.trg_notify_work_comment() from public, anon, authenticated;

drop trigger if exists trg_task_comments_notify on public.task_comments;
create trigger trg_task_comments_notify
  after insert on public.task_comments
  for each row execute function public.trg_notify_work_comment();
