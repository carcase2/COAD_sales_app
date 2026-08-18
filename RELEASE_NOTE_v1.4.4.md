# 출시명

**COAD DOOR v1.4.4 — 상담 예정일 바로 적용**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.4.4 상담 예정일 바로 적용`

**출시노트**  
```
• 상담 예정일을 고르면 확인 창 없이 바로 적용됩니다
• 그날 이미 예정된 건수는 입력 화면에 그대로 표시됩니다
• 버전 1.4.4 / 빌드 145
```

### 변경 요약
- **예정일**: 날짜 선택 후 확인 대화상자 없이 바로 반영
- **건수 안내**: 입력 시트에 해당일 예정 건수 표시 유지
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.4.4)
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.4.4** / versionCode **145**
