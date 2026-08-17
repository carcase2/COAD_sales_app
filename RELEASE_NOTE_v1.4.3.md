# 출시명

**COAD DOOR v1.4.3 — 내 발급요청**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.4.3 내 발급요청`

**출시노트**  
```
• 발급요청에서 내가 요청한 대기·발급됨만 바로 볼 수 있습니다
• 현장명·번호로 검색하고, 잔여 %를 이어서 요청할 수 있습니다
• 최근 내 요청을 불러와 같은 현장을 빠르게 등록합니다
• 버전 1.4.3 / 빌드 144
```

### 변경 요약
- **내 요청**: 내 대기·내 발급됨 목록, 등록 후 해당 건으로 이동
- **검색·잔여**: 현장명·번호 검색, 잔여 % 이어서 요청
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.4.3)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.4.3** / versionCode **144**
