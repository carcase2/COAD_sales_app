# 출시명

**COAD DOOR v0.18.8 — 발급 알림 수신 대상 개선**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.18.8 발급 알림 수신 대상 개선`

**출시노트**  
```
• 발급요청·완료 알림이 담당자와 관리자에게만 전달됩니다
• 다른 담당자 건 알림이 전체로 오던 문제를 수정했습니다
• 버전 0.18.8 / 빌드 97
```

### 변경 요약
- **발급 알림**: 관리자는 전체, 일반 사용자는 본인 담당 건만 수신 (이상수 팀장 요청)
- **서버**: `notify-issuance-request` Edge Function 수신자 필터 적용
- **앱**: 실시간 감시 로컬 알림도 동일 규칙 적용

### 배포 시 함께 필요
- Supabase: `supabase db push` + `supabase functions deploy notify-issuance-request`
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.18.8** / versionCode **97**
