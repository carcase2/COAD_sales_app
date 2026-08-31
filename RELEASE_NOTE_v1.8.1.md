# 출시명

**COAD DOOR v1.8.1 — 자동문의고수 알림**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.8.1 자동문의고수 알림`

**출시노트**  
```
• 웹·앱에서 자동문의고수 접수를 등록하면 관리자와 해당 부서 앱으로 알림이 갑니다
• 홈·접수·팔로업·달력 등 자동문의고수 기능을 계속 사용할 수 있습니다
• 버전 1.8.1 / 빌드 168
```

### 변경 요약
- **알림**: 웹·앱 접수 푸시가 관리자·자동문의고수 부서로 다시 전송됨
- **수정**: 없는 `users.permissions` 조회 제거, `users.group_id`/`groups`로 수신 대상 판별
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.8.1)
- Edge Function: `notify-gosu-reception` (재배포됨)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.8.1** / versionCode **168**
