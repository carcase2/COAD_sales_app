# 출시명

**COAD DOOR v0.18.4 — 통화상세 접수 일시 수정**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.18.4 통화상세 접수 일시 수정`

**출시노트**  
```
• 통화상세 접수 일시가 9시간 앞서 보이던 문제 수정
• call_date/call_time은 한국 시간 그대로 표시
• 버전 0.18.4 / 빌드 92
```

### 변경 요약
- **접수 일시**: `call_date`/`call_time`은 DB에 저장된 **KST 현지 시각**으로 표시 (불필요한 +9시간 제거)
- `created_at`만 있을 때는 기존처럼 UTC → KST 변환

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v0.18.4)
- Play: `build/app/outputs/bundle/release/app-release.aab` 업로드

### 버전 정보
- 버전: **0.18.4** / versionCode **92**
