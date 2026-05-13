# 출시명

**COAD DOOR v0.16.1 — 설정 업데이트 확인 개선**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 **0.16.1**로 올렸습니다.
- Android 배포 빌드 번호(`versionCode`)를 **39**로 올렸습니다.
- **설정 → 업데이트 확인**을 누를 때마다 Supabase `app_update_policy` 기준으로 다시 검사하도록 했습니다. (앱 시작 시 **선택 업데이트**를 **나중에**로 닫았어도, 설정에서 다시 안내가 뜨도록 수정)
- 설정 화면의 업데이트 항목 설명 문구를 보강했습니다.

### Play Console용 짧은 출시 노트 (복사용, 한국어)

**출시명 (예시)**  
`v0.16.1 설정 업데이트 확인 개선`

**출시 노트 (500자 이내 권장)**  
```
• 설정 > 업데이트 확인 시 Supabase 정책·Play 스토어를 다시 확인
• 앱 시작 후 '나중에'로 닫아도 설정에서 업데이트 안내 재표시
• 버전 0.16.1 / 빌드 39
```

### 반영 범위 (요약)
- `pubspec.yaml` (`0.16.1+39`)
- `lib/core/constants/app_meta.dart`
- `lib/services/app_update_service.dart`
- `lib/features/settings/settings_screen.dart`

### 버전 정보
- 버전: **v0.16.1**
- 빌드 번호(versionCode): **39**
- 배포 대상: Android (AAB)
