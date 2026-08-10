# 출시명

**COAD DOOR v1.3.1 — iOS 푸시·상담 입력 UX**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.3.1 iOS 푸시·상담 입력 UX`

**출시노트**  
```
• iPhone 푸시 알림(접수·발급)을 안정적으로 수신하고 탭 시 상세로 이동합니다
• 여러 기기(아이폰·안드로이드)에 동시에 알림이 가도록 토큰을 기기별로 관리합니다
• 상담 입력 시 키보드에 가려지지 않도록 시트를 개선했습니다
• 버전 1.3.1 / 빌드 138
```

### 변경 요약
- **iOS FCM**: APNs alert 푸시, APNs 토큰 대기 후 FCM 동기화, `registerForRemoteNotifications`
- **다중 기기**: `user_push_tokens` 기반 수신 + 레거시 `users.fcm_token` fallback
- **상담 시트**: 키보드 열림 시 요약 접기·스크롤로 입력 영역 확보
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.3.1)
- Edge Function: notify-* (이미 배포된 경우 생략 가능)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.3.1** / versionCode **138**
