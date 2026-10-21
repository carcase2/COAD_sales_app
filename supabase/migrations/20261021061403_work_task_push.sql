-- 업무 추가·상태 변경 푸시, 매일 08:00 KST 남은 업무·오늘 마감 푸시.
-- 수신 대상은 Edge Function notify-work-task 가 연구소·관리자 그룹으로 가른다.

create table if not exists public.work_push_dedup (
  dedupe_key text primary key,
  sent_at timestamptz not null default now()
);

alter table public.work_push_dedup enable row level security;

revoke all on table public.work_push_dedup from public, anon, authenticated;
grant all on table public.work_push_dedup to service_role;

create index if not exists work_push_dedup_sent_at_idx
  on public.work_push_dedup (sent_at);

create or replace function public.trg_notify_work_task()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
  kind text;
begin
  if tg_op = 'INSERT' then
    kind := 'added';
  elsif tg_op = 'UPDATE' then
    if new.status_id is not distinct from old.status_id then
      return new;
    end if;
    kind := 'status';
  else
    return new;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-work-task',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'kind', kind,
      'record', to_jsonb(new)
    )
  );
  return new;
exception
  when others then
    raise warning 'trg_notify_work_task failed: %', sqlerrm;
    return new;
end;
$$;

revoke all on function public.trg_notify_work_task() from public, anon, authenticated;

drop trigger if exists trg_tasks_notify_work_task on public.tasks;
create trigger trg_tasks_notify_work_task
  after insert or update of status_id on public.tasks
  for each row
  execute function public.trg_notify_work_task();

-- 08:00 KST = 23:00 UTC. pg_cron 이 없으면 아침 알림 스케줄만 건너뛴다.
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice 'pg_cron unavailable: %', sqlerrm;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('work-tasks-morning');
    exception
      when others then
        null;
    end;

    perform cron.schedule(
      'work-tasks-morning',
      '0 23 * * *',
      $cron$
      select net.http_post(
        url := 'https://qemerxtickpvjcgowyrd.supabase.co/functions/v1/notify-work-task',
        headers := '{"Content-Type":"application/json"}'::jsonb,
        body := '{"mode":"morning"}'::jsonb
      );
      $cron$
    );
  else
    raise notice 'pg_cron 없음. 아침 업무 알림 스케줄을 등록하지 못했습니다.';
  end if;
end;
$$;
