# 출시명

**COAD DOOR v1.1.2 — 접수 경과 시간(KST) 수정**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v1.1.2 접수 경과 시간 수정`

**출시노트**  
```
• 고객전화 접수 직후 「접수 후 9시간 경과」로 보이던 문제를 수정했습니다
• 접수 시각을 한국 시간(KST)으로 저장·표시하도록 맞췄습니다
• 버전 1.1.2 / 빌드 121
```

### 변경 요약
- **접수 등록**: `call_date`/`call_time`을 서울 시각으로 저장 (DB UTC 기본값 의존 제거)
- **접수 일시·경과**: UTC 벽시계를 KST로 오인한 경우 `created_at`으로 보정
- **제안**: 이상호 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.1.2)
- Play: `flutter build appbundle --release` 후 AAB 업로드

### 버전 정보
- 버전: **1.1.2** / versionCode **121**
