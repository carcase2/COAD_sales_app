# 출시명

**COAD DOOR v1.11.2 — 본사일반·대구지사 당겨서 새로고침**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.11.2 본사일반·대구지사 새로고침`

**출시노트**  
```
• 본사일반·대구지사 달력을 아래로 당기면 일정이 새로고침됩니다
• 버전 1.11.2 / 빌드 187
```

### 변경 요약
- **본사일반·대구지사**: 월간 달력에서도 당겨서 새로고침 (주간은 기존과 동일)
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.11.2)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.11.2** / versionCode **187**
