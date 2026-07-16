# 출시명

**COAD DOOR v1.1.4 — 관리자 그룹 알림 수신 개선**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v1.1.4 관리자 그룹 알림 수신 개선`

**출시노트**  
```
• 관리자 그룹에 소속된 직원도 발급요청·발급완료 알림을 받도록 수정했습니다
• 관리자 그룹에 소속된 직원도 고객접수 알림을 받도록 수정했습니다
• 고객접수 담당자 미지정 시 전체 알림 대신 관리자만 수신하도록 정리했습니다
• 버전 1.1.4 / 빌드 123
```

### 변경 요약
- **발급요청·완료 푸시**: `role=admin`뿐 아니라 **관리자 그룹** 소속도 수신
- **고객접수 푸시**: 동일하게 관리자 그룹 소속 포함, 담당자 미지정 시 관리자만 수신
- **제안**: 정나영 실장

### 배포 시 함께 필요
- Supabase: `supabase functions deploy notify-issuance-request notify-new-call`
- Supabase: `supabase db push` (업데이트 내역 v1.1.4)
- Play: `flutter build appbundle --release` 후 AAB 업로드

### 버전 정보
- 버전: **1.1.4** / versionCode **123**
