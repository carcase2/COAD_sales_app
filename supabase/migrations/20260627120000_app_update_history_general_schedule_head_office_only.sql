-- 본사일반 = 본사(본사영업·관리자)만 해당 안내 추가

update public.app_update_history
set release_notes = release_notes || jsonb_build_array(
  jsonb_build_object(
    'note',
    '본사일반 일정·FCM 알림은 본사(본사영업·관리자)에만 해당하며, 대구지사 등 다른 조직에는 적용되지 않습니다',
    'proposer',
    '김경덕 이사'
  )
)
where version in ('0.19.4', '0.19.5');
