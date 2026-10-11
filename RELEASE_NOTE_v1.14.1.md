# 출시명

**COAD DOOR v1.14.1 — 견적 탭 사용량**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.14.1 견적 탭 사용량`

**출시노트**  
```
• 앱 사용량에서 견적 메뉴를 셔터 견적기·표준단가·견적서로 나눠 봅니다
• 견적 메뉴에서 탭을 열거나 바꿀 때마다 사용 기록이 남습니다
• 버전 1.14.1 / 빌드 192
```

### 변경 요약
- **견적 허브**: 셔터 견적기(`shutter_quoter`), 표준단가(`standard_unit_price`), 견적서(`quoter_list`) 탭별 사용량 기록
- **앱 사용량**: 새 탭 키 라벨 추가
- **참고**: v1.10.0(2026-09-09)부터 이번 배포 전까지 표준단가 사용 기록은 누락
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.14.1)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 Transporter 업로드

### 버전 정보
- 버전: **1.14.1** / versionCode **192**
