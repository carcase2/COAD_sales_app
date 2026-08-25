# 출시명

**COAD DOOR v1.7.11 — 표준단가 전원 조회**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.11 표준단가 전원 조회`

**출시노트**  
```
• 사이즈 표준단가를 로그인한 사람이면 모두 조회할 수 있습니다
• 단가 수정은 인트라넷에서만 하고, 앱에서는 조회만 됩니다
• 버전 1.7.11 / 빌드 164
```

### 변경 요약
- **표준단가**: 전원 조회, 앱에서 일괄 조정·분류/모델 수정 숨김
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.11)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.11** / versionCode **164**
