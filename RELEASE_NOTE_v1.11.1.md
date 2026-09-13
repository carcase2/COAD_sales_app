# 출시명

**COAD DOOR v1.11.1 — 본사 영업 본사일반 복구**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.11.1 본사 영업 본사일반 복구`

**출시노트**  
```
• 본사 영업(박정훈·김인엽·이상호·이상수)에게 본사일반 일정이 다시 보입니다
• 버전 1.11.1 / 빌드 186
```

### 변경 요약
- **본사일반**: 부서 이름이 `영업`으로 바뀐 뒤에도 본사 지사면 본사일반 탭을 연다
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.11.1)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.11.1** / versionCode **186**
