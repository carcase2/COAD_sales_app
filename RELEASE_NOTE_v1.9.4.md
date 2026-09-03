# 출시명

**COAD DOOR v1.9.4 — 이행증권 요청 화면 정리**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.9.4 이행증권 요청 화면 정리`

**출시노트**  
```
• 이행증권 보증/기간을 증권 종류별 카드로 맞춰, 계약이행·선급금·하자이행을 같은 형식으로 입력합니다
• 시공 시작일·종료일을 한 줄로 고를 수 있습니다
• 발급요청 등록에서 세금계산서·이행증권 탭이 화면을 넘치지 않습니다
• 버전 1.9.4 / 빌드 177
```

### 변경 요약
- **이행증권**: 보증/기간 카드 UI 통일, 시공 기간 한 줄, 도메인 탭 overflow 수정
- **제안**: 이상수 팀장

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.9.4)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.9.4** / versionCode **177**
