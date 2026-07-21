# 출시명

**COAD DOOR v1.1.7 — Play 반영 전 업데이트 안내 개선**

## 출시 노트

### Play Console용 (복사용)

**출시명**  
`v1.1.7 Play 반영 전 업데이트 안내 개선`

**출시노트**  
```
• Play 스토어에 새 빌드가 올라오기 전에 업데이트 안내가 뜨던 문제를 개선했습니다
• 선택 업데이트는 Play에 실제 업데이트가 있을 때만 표시합니다
• Play 미반영 시에는 곧 반영된다는 안내만 보여 불필요한 재시도를 줄였습니다
• 버전 1.1.7 / 빌드 126
```

### 변경 요약
- **업데이트 UX**: 정책 `latest_version`만으로 선택 업데이트를 띄우지 않고, Play `InAppUpdate` 가능 여부를 함께 확인
- **제안**: 김경덕 이사

### 배포 시 함께 필요
- Supabase: `supabase db push` (업데이트 내역 v1.1.7)
- Play: `flutter build appbundle --release` 후 AAB 업로드

### 버전 정보
- 버전: **1.1.7** / versionCode **126**
