# 출시명

**COAD DOOR v0.16.12 — Android 포그라운드 알림 탭 상세 이동 수정**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.16.12 Android 앱 실행 중 알림 탭 상세 이동 수정`

**출시 노트**  
```
• 앱이 켜져 있을 때 알림을 눌렀을 때 해당 접수 상세로 이동하도록 수정
• 알림 탭 시 화면 전환 안정성 개선
• 버전 0.16.12 / 빌드 50
```

### 변경 요약
- `MainActivity.onNewIntent` — Android 알림 탭 Intent가 Flutter로 전달되도록 처리
- 포그라운드 알림 탭: 즉시 이동 + 재시도 + SharedPreferences 백업
- 앱 재개 시 보류 payload / launch details 소비 (`onAppResumed`)
- Navigator 최상단 route 기준으로 상세 화면 전환

### 버전 정보
- 버전: **0.16.12** / versionCode **50**
