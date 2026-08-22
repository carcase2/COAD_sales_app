# 출시명

**COAD DOOR v1.7.3 — 메일 발송**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.3 메일 발송`

**출시노트**  
```
• 메뉴에서 메일 발송을 열고 자료실 파일을 골라 보낼 수 있습니다
• 받는 사람은 명함에서 고르고, 보내는 사람은 로그인 계정으로 고정됩니다
• 보낸 메일에서 다시 보낼 수 있습니다
• 버전 1.7.3 / 빌드 156
```

### 변경 요약
- **메일**: COAD_home과 같은 자료실 발송, 명함 수신자, 발송 이력
- **제안**: 이상수 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.3)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.3** / versionCode **156**
