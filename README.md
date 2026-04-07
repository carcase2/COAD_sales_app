# 코아드 고객전화 (Android MVP)

Next.js 인트라넷과 동일한 REST API(`BASE_URL`)를 사용하는 Flutter **Android 전용** 고객전화 앱입니다. Material 3, UI 문자열 한국어.

## 요구 사항

- Flutter 3.x (Dart null-safety)
- Android **minSdk 24** 이상

## BASE_URL 설정

배포된 Next 앱 루트 URL을 사용합니다. **끝의 `/`는 붙이지 않습니다.**

### 1) 릴리스 빌드 시 고정 (권장)

```bash
flutter build apk --release \
  --dart-define=BASE_URL=https://your-deployment.example.com
```

`--dart-define`으로 넣은 값은 설정 화면 입력보다 **우선**합니다.

### 2) 디버그 / 내부 테스트

앱 **설정** 화면에서 `BASE_URL`을 저장하면 `shared_preferences`에 보관됩니다.  
`define`이 비어 있을 때만 사용됩니다.

## 권한

로그인 API 응답의 `user`에 대해 다음 중 하나일 때만 고객전화 화면으로 진입합니다.

- `role === "admin"`
- `permissions`에 `"all"` 또는 `"sales_calls"` 포함

## 사용 API (웹과 동일 경로)

| 메서드 | 경로 |
|--------|------|
| POST | `/api/auth/login` |
| GET | `/api/sales-calls/master-data` |
| GET | `/api/sales-calls` |
| GET | `/api/sales-calls/{id}` (상세 조회 — 서버에 라우트가 없으면 목록에서만 열기) |
| POST | `/api/sales-calls` |
| PUT | `/api/sales-calls/{id}` |
| GET | `/api/sales-calls/today-stats` |

## 인증 / 세션 (MVP)

- 로그인 성공 시 `user` JSON은 `flutter_secure_storage`에 저장합니다.
- `Set-Cookie`가 내려오면 같은 저장소에 문자열로 보관하고, 이후 요청에 `Cookie` 헤더로 전달합니다. (서버가 세션 쿠키만 쓰는 경우 대비)

## 릴리스 빌드 예시

```bash
cd /path/to/sales_app
flutter pub get
flutter build apk --release \
  --dart-define=BASE_URL=https://your-deployment.example.com
```

산출물: `build/app/outputs/flutter-apk/app-release.apk`

앱 서명은 Android Studio 또는 `key.properties`로 별도 구성하세요. 현재 템플릿은 디버그 키로 릴리스 서명될 수 있습니다.

## 프로젝트 구조 (`lib/`)

- `main.dart` — 타임존(Asia/Seoul), 의존성·세션 부트스트랩
- `app.dart` — MaterialApp, 로케일
- `core/` — 네트워크, 설정, 날짜·검증 유틸
- `data/` — 저장소, 리포지토리, `AuthController`
- `models/` — API 모델 (`fromJson` 유연 파싱)
- `features/` — 로그인, 홈, 목록·상세·등록, 설정

## 웹 코드와 필드 맞추기

COAD_home 쪽 `src/types/salesCalls.ts`, `src/app/api/sales-calls/*`, `src/app/api/auth/login/route.ts`의 JSON 키와 맞추려면 `lib/models/*.dart`와 `sales_calls_repository.dart`의 쿼리/바디만 조정하면 됩니다.
