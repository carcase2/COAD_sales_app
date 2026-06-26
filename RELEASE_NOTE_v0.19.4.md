# 출시명

**COAD DOOR v0.19.4 — 본사일반 일정 FCM 알림**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.19.4 본사일반 일정 FCM 알림`

**출시노트**  
```
• 본사일반 일정 변경 시 본사영업·관리자에게 푸시 알림이 갑니다
• 알림에 입력자·이달 남은 빈 칸·가장 빠른 빈 칸 날짜가 표시됩니다
• 알림 탭 시 본사일반 일정 화면으로 이동합니다
• 버전 0.19.4 / 빌드 103
```

### 변경 요약
- **본사일반**: 등록·수정·삭제 시 FCM 푸시 (본사영업·관리자만, 김경덕 이사 제안)
- 전화접수·발급완료와 동일한 data-only FCM 패턴
- Edge Function `notify-general-schedule` (배포 완료)

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v0.19.4)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.19.4** / versionCode **103**
