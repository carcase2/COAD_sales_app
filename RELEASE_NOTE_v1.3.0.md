# 출시명

**COAD DOOR v1.3.0 — 대구지사 일정**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v1.3.0 대구지사 일정`

**출시노트**  
```
• 대구지사장·관리자용 「대구지사」 일정 탭을 추가했습니다
• 본사일반과 동일한 일정 UI로 대구 전용 테이블·알림을 분리했습니다
• 푸시 알림으로 대구지사 일정 등록·변경을 받을 수 있습니다
• 버전 1.3.0 / 빌드 131
```

### 변경 요약
- **대구지사 일정**: `ScheduleBranch`로 본사일반과 테이블·권한·FCM 분기
- **네비**: 권한 있는 사용자에게 대구지사 탭 표시
- **알림**: `notify-daegu-schedule` Edge Function
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.3.0)
- Edge Function: `notify-daegu-schedule` 배포(미배포 시)
- Play: `flutter build appbundle --release` 후 AAB 업로드

### 버전 정보
- 버전: **1.3.0** / versionCode **131**
