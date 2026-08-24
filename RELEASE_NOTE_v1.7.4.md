# 출시명

**COAD DOOR v1.7.4 — 홈 카드 확대**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.4 홈 카드 확대`

**출시노트**  
```
• 홈 영업부·고객지원팀 카드 글자와 터치 영역을 키웠습니다
• 홈에서 영업부와 고객지원팀 현황을 모두 볼 수 있습니다
• 버전 1.7.4 / 빌드 157
```

### 변경 요약
- **홈**: 통계 카드 크기 확대 (Android·iOS 동일)
- **홈**: 고객지원팀 카드를 전원에게 표시 (스크롤 허용)
- **제안**: 홍창우 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.4)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.4** / versionCode **157**
