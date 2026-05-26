# 출시명

**COAD DOOR v0.16.5 — 홈 허브·달력 금주·미통화 금년**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 **0.16.5**로 올렸습니다.
- Android 배포 빌드 번호(`versionCode`)를 **43**으로 올렸습니다.
- **홈 허브**를 흐름 / 미통화 / 달력 한 화면에서 전환하도록 정리하고, 구역별 배경·탭 UI를 다듬었습니다.
- **달력** 탭에서 주간 보기 진입·전환 시 **금주**가 기본으로 맞춰지고, 주간 라벨에 `금주` 표시가 나옵니다. (이전 주가 남아 4/27~5/3 등으로 보이던 문제 수정)
- **미통화** 탭에 **금년** 기간 필터를 추가하고, 기간별 조회·연도 단위 페이지네이션으로 목록 1000건 제한을 완화했습니다.
- 미통화 담당자 그리드를 스크롤로 전체 표시하고, 타일·전일 대비 카드 레이아웃을 조정했습니다.
- 흐름 탭 **금일 접수** 탭 시 담당자별 접수 목록(바텀시트), 로그인 담당자 자동 이동·길게 눌러 담당자 선택을 지원합니다.
- **전화번호 검색** 시 하이픈 포함 입력(`010-5660-6005` 등)도 동일하게 찾을 수 있습니다.
- 상담 등록·상세 화면 UX를 일부 개선했습니다.

### Play Console용 (복사용, 한국어)

**출시명**  
`v0.16.5 홈 달력 금주·미통화 금년`

**출시 노트** (500자 이내 권장)  
```
• 홈: 흐름·미통화·달력 허브 화면 정리 및 UI 개선
• 달력 주간: 탭 진입 시 금주로 맞춤, 금주 표시 (잘못된 과거 주 선택 수정)
• 미통화: 금년 필터 추가, 기간별 집계·목록 조회 개선
• 미통화 담당자 목록 전체 스크롤, 흐름 금일 접수 담당자별 보기
• 전화번호 검색 시 하이픈(010-xxxx-xxxx) 입력 지원
• 버전 0.16.5 / 빌드 43
```

### 반영 범위 (요약)
- `pubspec.yaml` (`0.16.5+43`)
- `lib/core/constants/app_meta.dart`
- `lib/core/utils/date_seoul.dart`, `phone_validation.dart`
- `lib/features/home/home_hub_screen.dart`, `home_screen.dart`, `home_providers.dart`, `home_navigation.dart`
- `lib/features/main/main_tab_screen.dart`
- `lib/data/sales_calls_repository.dart`
- `lib/features/sales_calls/*` (목록·검색·등록·상세 일부)

### 버전 정보
- 버전: **v0.16.5**
- 빌드 번호(versionCode): **43**
- 배포 대상: Android (AAB)
- 산출물: `build/app/outputs/bundle/release/app-release.aab`

### 배포 시 참고
- Play **내부 테스트** 또는 프로덕션 트랙에 AAB 업로드 후 **출시 완료**까지 진행합니다.
- `app_update_policy.latest_version`을 **0.16.5**로 맞추면 앱 내 업데이트 안내가 정확해집니다.
- 프로덕션 API URL이 필요하면 `--dart-define=BASE_URL=…`로 AAB를 다시 빌드합니다.
