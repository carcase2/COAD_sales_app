# 출시명

**COAD DOOR v1.7.0 — 고객지원 A/S**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.0 고객지원 A/S`

**출시노트**  
```
• 고객지원 A/S 접수·상담·방문 기록을 앱에서 처리할 수 있습니다
• 방문·발송 예정 캘린더와 알림을 확인할 수 있습니다
• 고객지원 견적서·단가표와 현장 지도를 쓸 수 있습니다
• 견적서를 이미지·PDF로 저장하고 이메일로 보낼 수 있습니다
• 버전 1.7.0 / 빌드 153
```

### 변경 요약
- **접수**: A/S 접수 저장·첨부·주소 검색, 1차 상담
- **일정**: 방문·발송 예정 캘린더, 방문 인원, 입금일, 재방문
- **견적**: 고객지원 견적서·단가표, 이미지·PDF 저장, 이메일 발송
- **지도**: 미처리·방문 현장을 가까운 순으로 표시, 지사 선택·색 구분
- **제안**: 남현우 팀장 (iOS A/S)

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.0)
- Edge Function: `notify-as-reception` / `notify-as-due-schedule`
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.0** / versionCode **153**
