# 출시명

**COAD DOOR v1.7.5 — 홈 전일 대비 문구**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.5 홈 전일 대비 문구`

**출시노트**  
```
• 홈 영업부 전일 대비 접수에서 현재·이전 건수가 잘리지 않게 두 줄로 표시합니다
• 버전 1.7.5 / 빌드 158
```

### 변경 요약
- **홈**: 전일 대비 접수 배너를 두 줄로 나눠 현재/이전 건수가 잘리지 않게 함
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.5)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.5** / versionCode **158**
