# Release Checklist

## Version Rules
- `pubspec.yaml`의 `version`은 항상 `X.Y.Z+N` 형식으로 관리한다.
- 사용자 표시 버전(`X.Y.Z`)은 기능/수정 단위로 증가시킨다.
- Android `versionCode`(`+N`)는 **배포할 때마다 반드시 +1** 한다.
- `lib/core/constants/app_meta.dart`의 `kAppVersion`은 `X.Y.Z`와 동일하게 맞춘다.

## Pre-Release
- `git status` 확인 (의도한 변경만 포함).
- 릴리스 노트 파일 추가/수정 (`RELEASE_NOTE_vX.Y.Z.md`).
- **설정 > 업데이트 내역**용 Supabase 마이그레이션 추가:
  - `supabase/migrations/*_seed_app_update_history_vX_Y_Z.sql`
  - `app_update_history`에 버전·변경 요약 insert
  - `app_update_policy.latest_version`을 배포 버전으로 갱신
- 배포 전/후 원격 DB 반영: `supabase db push` (또는 Dashboard SQL 실행)
- 업데이트 정책 사용 시 `app_update_policy` 값 점검:
  - `latest_version`: 최신 표시 버전
  - `min_version`: 강제 업데이트 하한 버전
  - `force_update`: 필요 시 `true`

## Build
- 릴리스 AAB 빌드:
  - `flutter build appbundle --release`
- 산출물 확인:
  - `build/app/outputs/bundle/release/app-release.aab`

## Play Console Upload
- 올릴 AAB의 `versionCode`가 기존보다 큰지 확인.
- 대상 트랙(내부/비공개/프로덕션) 선택 후 릴리스 생성.
- 릴리스 노트 입력 후 **출시 완료 상태**까지 진행.

## Smoke Test (핵심)
- Play 스토어 설치본에서 앱 실행 확인.
- 푸시 알림 탭 시 해당 상세 화면 진입 확인.
- 구버전 설치 기기에서 업데이트 감지 확인.
- 고객전화 수동 테스트: `docs/TEST_CHECKLIST_SALES_CALLS.md` (접수·푸시·상담내용·팔로우).

## Troubleshooting
- `버전 코드는 이미 사용되었습니다`:
  - `pubspec.yaml`의 `+N`을 1 올리고 다시 빌드.
- `(unreviewed)` 또는 내부 앱 공유 설치본에서 업데이트 실패:
  - 앱 삭제 후 Play 스토어 트랙 설치본으로 재설치.
- 업데이트가 바로 안 뜸:
  - Play 전파 지연 가능성(수분~수시간), 계정/트랙 권한 확인.
