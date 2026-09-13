# 출시명

**COAD DOOR v1.11.0 — 영업 지사·직책 권한**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.11.0 영업 지사·직책 권한`

**출시노트**  
```
• 로그인하면 이름 아래에 지사·직책이 보입니다
• 본사 영업은 본사일반 일정을 봅니다
• 대구 영업 지사장은 대구지사 일정을 봅니다
• 버전 1.11.0 / 빌드 185
```

### 변경 요약
- **로그인**: 메뉴에 `이름님`과 그 아래 `지사, 직책` 표시
- **대구지사**: 부서 영업 + 지사 대구 + 직책 지사장만 접근 (이영석)
- **본사일반**: 본사 영업(박정훈·김인엽·이상호·이상수) 유지
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.11.0), `notify-daegu-schedule` 함수 배포
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.11.0** / versionCode **185**
