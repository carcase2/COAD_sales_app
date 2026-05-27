# 출시명

**COAD DOOR v0.16.9 — 푸시 알림 탭 시 접수 상세 이동**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.16.9 푸시 탭 시 접수 상세 이동 수정`

**출시 노트**  
```
• 새 접수 푸시 알림을 누르면 해당 통화 상세 화면으로 이동하도록 수정
• 앱이 꺼져 있거나 백그라운드일 때도 알림 탭 동작 안정화
• 접수 등록 완료 알림 탭 시에도 해당 접수 상세로 이동
• 버전 0.16.9 / 빌드 47
```

### 변경 요약
- FCM 수신 시 로컬 알림에 `call_id` payload를 넣어 탭 시 `SalesCallDetailScreen`으로 이동
- cold start·백그라운드 탭·앱 재개 시 상세 이동 재시도
- 접수 완료 로컬 알림에도 `call_id` payload 추가
- Edge Function `notify-new-call`: data-only + 앱 로컬 알림 표시

### 배포 시 함께 필요
- Supabase: `supabase functions deploy notify-new-call`
- Play: `build/app/outputs/bundle/release/app-release.aab`

### 버전 정보
- 버전: **0.16.9** / versionCode **47**
