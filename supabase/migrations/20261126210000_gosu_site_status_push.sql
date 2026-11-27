-- 고수 홈페이지 문의가 접수중 → 접수완료 / 취소 로 바뀌면 푸시 (5분 동기화가 gosu_status_history 에 기록).
-- 그 밖의 단계 변화(실측완료·계약 등)는 알리지 않는다. 함수는 notify-gosu-reception (table=gosu_status_history).

create or replace function public.trg_notify_gosu_site_status()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  project_url text := 'https://qemerxtickpvjcgowyrd.supabase.co';
  site jsonb;
begin
  if NEW.from_status is distinct from '접수중'
     or NEW.to_status not in ('접수완료', '취소') then
    return NEW;
  end if;

  select to_jsonb(s) - 'image_urls' - 'install_image_urls' into site
  from public.gosu_sites s
  where s.gosu_id = NEW.gosu_id;

  perform net.http_post(
    url := project_url || '/functions/v1/notify-gosu-reception',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'gosu_status_history',
      'record', coalesce(site, jsonb_build_object('gosu_id', NEW.gosu_id))
        || jsonb_build_object(
          'history_id', NEW.id,
          'from_status', NEW.from_status,
          'to_status', NEW.to_status
        )
    )
  );
  return NEW;
exception
  when others then
    raise warning 'trg_notify_gosu_site_status failed: %', SQLERRM;
    return NEW;
end;
$$;

drop trigger if exists trg_gosu_status_history_notify on public.gosu_status_history;
create trigger trg_gosu_status_history_notify
  after insert on public.gosu_status_history
  for each row
  execute function public.trg_notify_gosu_site_status();
