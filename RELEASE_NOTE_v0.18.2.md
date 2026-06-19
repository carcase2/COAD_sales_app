# 출시명

**COAD DOOR v0.18.2 — 접수 알림·접수 일시 개선**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.18.2 접수 알림·접수 일시 개선`

**출시노트**  
```
• 신규 접수 푸시: 담당자·관리자만 수신 (담당자 미지정 시 기존처럼 전체)
• 고객전화 접수 일시를 한국 시간(KST)으로 통일 표시 (9시간 어긋남 수정)
• 목록·상세·미통화 접수일 계산 규칙 일치
• 버전 0.18.2 / 빌드 90
```

### 변경 요약
- **접수 푸시** (`notify-new-call`): 담당자 지정 시 관리자 + 해당 담당자만, 미지정 시 전체 브로드캐스트
- **접수 일시**: `call_date`/`call_time` UTC → KST 변환, 목록·상세·접수일 집계 동일 규칙

### 배포 시 함께 필요
- Supabase: `supabase functions deploy notify-new-call`
- Supabase: `supabase db push` (업데이트 내역 v0.18.2)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.18.2** / versionCode **90**
