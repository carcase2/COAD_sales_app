# 출시명

**COAD DOOR v1.6.0 — 고객지원 A/S**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.6.0 고객지원 A/S`

**출시노트**  
```
• 고객지원 A/S 접수·상담·방문 기록을 앱에서 처리할 수 있습니다
• 방문·발송 예정 캘린더와 알림을 확인할 수 있습니다
• 버전 1.6.0 / 빌드 149
```

### 변경 요약
- **접수**: A/S 접수 저장·첨부·주소 검색
- **일정**: 방문·발송 예정 캘린더, 1차 상담, 현장 방문 기록
- **알림**: 접수·예정 일정 알림
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.6.0)
- Edge Function: `notify-as-reception` / `notify-as-due-schedule`
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.6.0** / versionCode **149**
