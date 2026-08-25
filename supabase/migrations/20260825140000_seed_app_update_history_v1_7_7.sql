-- v1.7.7: MES 메뉴 (제안: 박정훈 상무)

insert into public.app_update_history (
  version,
  proposer,
  release_notes,
  created_at,
  is_visible
)
select
  '1.7.7',
  '박정훈 상무',
  jsonb_build_array(
    jsonb_build_object(
      'note',
      'MES 홈·영업등록·달력·시공완료·수금 메뉴를 권한에 따라 사용할 수 있습니다',
      'proposer',
      '박정훈 상무'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 중간 사이즈 예상단가를 보여주고, 테스트중 표시를 뺐습니다',
      'proposer',
      '박정훈 상무'
    )
  ),
  now(),
  true
where not exists (
  select 1
  from public.app_update_history
  where version = '1.7.7'
);

update public.app_update_history
set
  proposer = '박정훈 상무',
  release_notes = jsonb_build_array(
    jsonb_build_object(
      'note',
      'MES 홈·영업등록·달력·시공완료·수금 메뉴를 권한에 따라 사용할 수 있습니다',
      'proposer',
      '박정훈 상무'
    ),
    jsonb_build_object(
      'note',
      '사이즈 표준단가에서 중간 사이즈 예상단가를 보여주고, 테스트중 표시를 뺐습니다',
      'proposer',
      '박정훈 상무'
    )
  ),
  created_at = now(),
  is_visible = true
where version = '1.7.7';

update public.app_update_policy
set
  latest_version = '1.7.7',
  updated_at = now()
where is_active = true;
