# 출시명

**COAD DOOR v0.17.4 — 발급 완료 알림·상세 이동**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.17.4 발급 완료 알림·상세 이동`

**출시노트**  
```
• 발급 완료 시 푸시 알림 수신 (웹 발급 처리 포함)
• 발급요청·발급완료 알림 탭 시 세부내용 화면으로 바로 이동
• 버전 0.17.4 / 빌드 85
```

### 변경 요약
- **발급 완료 푸시**: 웹에서 이미지 업로드(발급 처리) 시 앱으로 FCM 알림 전송
- **알림 탭**: 등록·완료 알림을 누르면 해당 건 세부내용(bottom sheet)으로 직접 이동
- **서버**: 발급 완료 UPDATE 트리거 + Edge Function `notify-issuance-request` 확장 (배포 완료)

### 배포 시 함께 필요
- Supabase: `20260610160000_issuance_completed_push_webhook.sql` + 함수 재배포 (이미 적용된 경우 생략 가능)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.17.4** / versionCode **85**
