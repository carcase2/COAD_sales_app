-- Android는 v1.5.1이 마지막 스토어 배포. iOS 전용 1.5.2·1.6.0 안내를 숨긴다.

update public.app_update_history
set is_visible = false
where version in ('1.5.2', '1.6.0');

update public.app_update_policy
set
  latest_version = '1.5.1',
  updated_at = now()
where is_active = true;
