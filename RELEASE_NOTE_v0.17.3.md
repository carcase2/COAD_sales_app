# 출시명

**COAD DOOR v0.17.3 — 발급요청 알림 안정화**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.17.3 발급요청 알림 안정화`

**출시노트**  
```
• 긴급 발급요청 알림이 두 번 오던 문제 수정
• 발급요청 알림 탭 시 세부내용 화면으로 이동
• 웹에서 등록한 발급요청도 푸시 알림 수신
• 버전 0.17.3 / 빌드 84
```

### 변경 요약
- **긴급 세금계산서**: invoice·issue 동시 등록 시 푸시 1회만 발송
- **알림 탭**: 발급요청 알림을 누르면 해당 건 세부내용(bottom sheet)으로 이동
- **웹 등록**: COAD_home에서 등록해도 앱 푸시 수신 (서버 트리거)

### 배포 시 함께 필요
- Supabase: `supabase db push` + `supabase functions deploy notify-issuance-request` (이미 적용된 경우 생략 가능)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.17.3** / versionCode **84**
