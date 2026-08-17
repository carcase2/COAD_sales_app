# 출시명

**COAD DOOR v1.4.1 — 상담 예정일 건수 안내**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.4.1 상담 예정일 건수 안내`

**출시노트**  
```
• 상담내용 입력 시 다음 예정일을 고르면 그날 이미 예정된 건수를 보여줍니다
• 건수를 확인한 뒤 이 날짜로 두거나 다른 날을 다시 선택할 수 있습니다
• 버전 1.4.1 / 빌드 142
```

### 변경 요약
- **예정일 확인**: 날짜 선택 후 해당일 팔로우 예정 건수 안내
- **다른 날 선택**: 확인 창·날짜 필드에서 재선택 가능
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.4.1)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.4.1** / versionCode **142**
