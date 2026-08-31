# 출시명

**COAD DOOR v1.8.0 — 자동문의고수 알림**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.8.0 자동문의고수 알림`

**출시노트**  
```
• 자동문의고수 접수 시 관리자와 해당 부서에 알림이 더 안정적으로 갑니다
• 홈·접수·팔로업·달력 등 v1.7.13 자동문의고수 기능을 포함합니다
• 버전 1.8.0 / 빌드 167
```

### 변경 요약
- **알림**: 관리자·자동문의고수 부서 FCM 수신 대상·재시도 보완
- **푸시**: 웹·앱 접수 INSERT 공통 알림
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.8.0)
- Edge Function: `notify-gosu-reception` (재배포됨)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.8.0** / versionCode **167**
