# 출시명

**COAD DOOR v0.16.3 — Play 설치본 로그인·내부 테스트 재배포**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 **0.16.3**으로 올렸습니다.
- Android 배포 빌드 번호(`versionCode`)를 **41**로 올렸습니다.
- **Play 내부 테스트 설치본에서 로그인이 되지 않던 문제**를 해결하기 위해, 빌드 시 `.env`의 Supabase 설정이 AAB에 포함되도록 **릴리스 AAB를 재생성**했습니다.
- Supabase 초기화 시 `.env` 키 이름 fallback을 보강했습니다. (`NEXT_PUBLIC_SUPABASE_*` 외 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 등)
- Android 릴리스 서명 keystore 경로 해석을 수정했습니다. (`storeFile` → `rootProject.file`)
- 발급요청(세금계산서) 목록·완료 알림 제목에서 존재하지 않는 `company_name` 컬럼 참조를 제거했습니다.

### Play Console용 짧은 출시 노트 (복사용, 한국어)

**출시명 (예시)**  
`v0.16.3 Play 로그인 수정·내부 테스트 재배포`

**출시 노트 (500자 이내 권장)**  
```
• Play 스토어(내부 테스트) 설치본 로그인 오류 수정 — Supabase 설정이 포함된 AAB로 재배포
• Supabase 환경 변수 키 fallback 보강
• 세금계산서 발급요청 제목 표시 오류 수정
• 버전 0.16.3 / 빌드 41
```

### 반영 범위 (요약)
- `pubspec.yaml` (`0.16.3+41`)
- `lib/core/constants/app_meta.dart`
- `lib/main.dart`
- `android/app/build.gradle.kts`
- `lib/features/issuance/issuance_request_provider.dart`
- `lib/features/main/main_tab_screen.dart`

### 버전 정보
- 버전: **v0.16.3**
- 빌드 번호(versionCode): **41**
- 배포 대상: Android (AAB)
- 산출물: `build/app/outputs/bundle/release/app-release.aab`

### 배포 시 참고
- 테스터 기기: 기존 앱 **삭제 후** 내부 테스트 링크로 재설치 권장 (이전 `(unreviewed)`·내부 앱 공유 설치본 잔여 방지).
- `app_update_policy` 사용 시 `latest_version`을 **0.16.3** 이상으로 맞춰 주세요.
