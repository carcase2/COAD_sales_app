-- 고수 사이트 홈페이지 문의(gosu_sites)가 새로 들어오면 전화 접수처럼 FCM 푸시.
-- 1) coad-gosu-followup 동기화를 5분마다(07~22시 KST) 부른다 — 새 문의가 DB에 들어오도록.
-- 2) gosu_sites INSERT 시 notify-gosu-reception 함수(table=gosu_sites)를 부른다.
--
-- 사전 준비(마이그레이션 밖, 토큰은 저장소에 두지 않는다):
--   select vault.create_secret('<coad-gosu-followup SYNC_TOKEN>', 'gosu_sync_token', '고수 동기화 POST /api/sync 토큰');

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ---- 2) 새 문의 푸시 ----
create or replace function public.trg_notify_gosu_site_reception()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
begin
  -- 동기화는 upsert 라 기존 건은 UPDATE 로 들어온다. 과거 건 일괄 적재(backfill) 때 알림 폭주 방지로 최근 접수만.
  if NEW.received_at < now() - interval '6 hours' then
    return NEW;
  end if;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-gosu-reception',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'gosu_sites',
      'record', to_jsonb(NEW) - 'image_urls' - 'install_image_urls'
    )
  );
  return NEW;
exception
  when others then
    raise warning 'trg_notify_gosu_site_reception failed: %', SQLERRM;
    return NEW;
end;
$$;

drop trigger if exists trg_gosu_sites_notify_reception on public.gosu_sites;
create trigger trg_gosu_sites_notify_reception
  after insert on public.gosu_sites
  for each row
  execute function public.trg_notify_gosu_site_reception();

-- ---- 1) 5분마다 동기화 (07:00~21:55 KST = UTC 22~23시, 0~12시) ----
select cron.unschedule(jobid) from cron.job where jobname = 'gosu-site-sync';
select cron.schedule(
  'gosu-site-sync',
  '*/5 0-12,22-23 * * *',
  $cron$
    select net.http_post(
      url := 'https://coad-gosu-followup.vercel.app/api/sync',
      headers := jsonb_build_object(
        'x-sync-token',
        (select decrypted_secret from vault.decrypted_secrets where name = 'gosu_sync_token' limit 1)
      ),
      timeout_milliseconds := 60000
    );
  $cron$
);
