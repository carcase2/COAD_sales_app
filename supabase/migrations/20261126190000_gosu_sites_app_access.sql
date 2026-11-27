-- 고수 동기화(coad-gosu-followup) 테이블을 영업부 앱(anon 키)에서 보고 통화 기록을 남길 수 있게 한다.
-- 동기화(gosu_sites 쓰기)는 계속 coad-gosu-followup 서버(service_role)만 한다.
-- 앱은 읽기 + gosu_site_followups 추가만. 수정·삭제는 막아 둔다.

drop policy if exists "app read gosu_sites" on public.gosu_sites;
create policy "app read gosu_sites"
  on public.gosu_sites for select to anon, authenticated using (true);

drop policy if exists "app read gosu_site_followups" on public.gosu_site_followups;
create policy "app read gosu_site_followups"
  on public.gosu_site_followups for select to anon, authenticated using (true);

drop policy if exists "app insert gosu_site_followups" on public.gosu_site_followups;
create policy "app insert gosu_site_followups"
  on public.gosu_site_followups for insert to anon, authenticated
  with check (length(btrim(author)) > 0 and length(btrim(result)) > 0);

drop policy if exists "app read gosu_status_history" on public.gosu_status_history;
create policy "app read gosu_status_history"
  on public.gosu_status_history for select to anon, authenticated using (true);

drop policy if exists "app read gosu_sync_runs" on public.gosu_sync_runs;
create policy "app read gosu_sync_runs"
  on public.gosu_sync_runs for select to anon, authenticated using (true);
