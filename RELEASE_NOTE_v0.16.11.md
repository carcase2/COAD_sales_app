# 출시명

**COAD DOOR v0.16.11 — Android 푸시 알림 탭 시 통화 상세 이동 안정화**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v0.16.11 Android 알림 탭 시 통화 상세 이동 안정화`

**출시 노트**  
```
• 앱이 열려 있을 때 알림을 눌렀을 때 해당 접수 상세로 이동하도록 개선
• 다른 통화 상세 화면에서 알림 탭 시 올바른 접수로 전환
• data-only 푸시에서도 알림이 표시되도록 개선
• 버전 0.16.11 / 빌드 49
```

### 변경 요약
- 포그라운드 푸시 수신 시 자동 상세 이동 제거 → **알림 탭 시에만** 이동
- 알림 탭·네비게이션 재시도 충돌 방지(최신 알림만 처리)
- 이미 통화 상세 화면일 때 `pushReplacement`로 대상 접수로 전환
- 제목/본문 없는 data-only 푸시에 기본 알림 문구 표시
- Android FCM 기본 알림 채널 `high_importance_channel` 지정

### 배포 시 함께 필요
- Play: `build/app/outputs/bundle/release/app-release.aab`
- (선택) Supabase `app_update_policy.latest_version` → `0.16.11`

### 버전 정보
- 버전: **0.16.11** / versionCode **49**
