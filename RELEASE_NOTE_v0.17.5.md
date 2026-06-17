# 출시명

**COAD DOOR v0.17.5 — 발급 알림 안정화·전일 미통화**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.17.5 발급 알림 안정화·전일 미통화`

**출시노트**  
```
• 발급 완료 푸시 알림 및 알림 탭 시 세부내용 이동
• 알림 탭 후 상세 반복 열림·발급대기 로딩 멈춤 수정
• 흐름 탭 전일 미통화 카드 — 어제 접수 미통화 확인·목록 이동
• 버전 0.17.5 / 빌드 87
```

### 변경 요약
- **발급 완료 푸시**: 웹 발급 처리 시 FCM 알림 + 탭 시 세부내용 이동
- **알림 안정화**: 상세 반복 열림·발급대기 로딩 멈춤 수정
- **흐름 탭**: 전일 미통화 카드(0건 포함) — 탭 시 전일 미통화 목록

### 배포 시 함께 필요
- Supabase: `supabase db push` + `supabase functions deploy notify-issuance-request`
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.17.5** / versionCode **87**
