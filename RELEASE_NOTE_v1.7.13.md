# 출시명

**COAD DOOR v1.7.13 — 자동문의고수**

## 출시 노트

### Play Console / TestFlight용 (복사용)

**출시명**  
`v1.7.13 자동문의고수`

**출시노트**  
```
• 홈에서 자동문의고수 부서를 볼 수 있고, 하단 접수는 보고 있는 부서 탭으로 열립니다
• 자동문의고수 접수·팔로업·달력을 앱에서 처리할 수 있습니다
• 자동문의고수 접수가 등록되면 관리자와 해당 부서에 알림이 갑니다
• 버전 1.7.13 / 빌드 166
```

### 변경 요약
- **홈·접수**: 자동문의고수 부서 탭, 하단 접수가 영업/A/S/고수 중 현재 홈 부서를 선택
- **고수**: 접수·목록 필터·팔로업·달력, 접수 시 관리자·자동문의고수 부서 푸시
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.7.13)
- Edge Function: `notify-gosu-reception`
- Play: `flutter build appbundle --release` 후 AAB 업로드
- iOS: `flutter build ipa --release` 후 TestFlight 업로드

### 버전 정보
- 버전: **1.7.13** / versionCode **166**
