# 출시명

**COAD DOOR v0.16.4 — 설정 업데이트 확인 즉시 갱신**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 **0.16.4**로 올렸습니다.
- Android 배포 빌드 번호(`versionCode`)를 **42**로 올렸습니다.
- **설정 → 업데이트 확인** 동작을 개선했습니다.
  - Supabase 정책·안내창보다 **Play 인앱 업데이트를 먼저** 시도합니다.
  - 인앱 업데이트가 없으면 **Play 스토어 앱 페이지**(`market://`)로 이동해 스토어에서 [업데이트]를 누를 수 있게 했습니다.
  - 정책 `store_url`이 있으면 해당 링크를 우선 사용합니다.
- 업데이트 확인을 여러 번 눌러도 재시도되도록 세션 플래그 처리를 조정했습니다.

### Play Console용 짧은 출시 노트 (복사용, 한국어)

**출시명 (예시)**  
`v0.16.4 설정 업데이트 확인 개선`

**출시 노트 (500자 이내 권장)**  
```
• 설정 > 업데이트 확인 시 Play 인앱 업데이트를 바로 시도
• 인앱 업데이트 불가 시 Play 스토어 앱 페이지로 이동
• v0.16.1 등 구버전에서 최신 버전으로 갱신 용이
• 버전 0.16.4 / 빌드 42
```

### 반영 범위 (요약)
- `pubspec.yaml` (`0.16.4+42`)
- `lib/core/constants/app_meta.dart`
- `lib/services/app_update_service.dart`
- `lib/features/settings/settings_screen.dart`

### 버전 정보
- 버전: **v0.16.4**
- 빌드 번호(versionCode): **42**
- 배포 대상: Android (AAB)
- 산출물: `build/app/outputs/bundle/release/app-release.aab`

### 배포 시 참고
- Play **내부 테스트**에 AAB 업로드 후 **출시 완료** 필요 (0.16.1 → 0.16.4는 versionCode 39 → 42).
- `app_update_policy.latest_version`을 **0.16.4**로 맞추면 안내 메시지가 정확해집니다.
- 인앱 업데이트는 **Play 스토어로 설치한 앱**에서만 동작합니다. 실패 시 스토어 페이지로 이동합니다.
- 테스터: 기존 앱 삭제 후 internaltest 링크 재설치도 가능합니다.
