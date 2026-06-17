# 출시명

**COAD DOOR v0.17.1 — 발급요청 등록 알림 복구**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.17.1 발급요청 등록 알림 복구`

**출시노트**  
```
• 발급요청 등록 시 푸시·로컬 알림 복구
• 버전 0.17.1 / 빌드 82
```

### 변경 요약
- **발급요청**: 등록 직후 로컬 알림 + FCM 푸시(`notify-issuance-request`) 호출 복구
- v0.17.0에서 빠졌던 등록 알림 경로 정리

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역·정책)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.17.1** / versionCode **82**
