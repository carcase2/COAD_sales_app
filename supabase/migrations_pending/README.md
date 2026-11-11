# 로그인 비밀번호 서버 검증 (적용 대기)

이 폴더의 SQL은 **아직 운영 DB에 적용하지 않았다.** `supabase db push`에 실수로 섞이지 않도록 `migrations/` 밖에 둔다.
승인을 받으면 순서대로 `supabase/migrations/`로 옮겨 적용한다.

## 확인 결과 (2026-11-11, 프로젝트 qemerxtickpvjcgowyrd)

- `users.password`: 81행 모두 평문(4~12자). 35행은 4자 이하, 9행은 `1234`.
- `users`는 RLS가 켜져 있지만, 정책에 `Allow all`(ALL, 대상 public, `true`)과 `users_select_anon`(`true`)이 있다.
  anon 역할도 테이블에 SELECT/INSERT/UPDATE/DELETE/TRUNCATE 권한이 있다.
- 결과: 앱에 들어 있는 anon 키만 있으면 누구나
  - 전 직원의 아이디·평문 비밀번호·전화·이메일·FCM 토큰을 읽고,
  - 아무 계정의 비밀번호·역할·권한 그룹을 바꾸고, 계정을 지울 수 있다.
- 같은 평문 비교를 쓰는 곳: 영업 앱 `auth_repository.dart`, COAD_home `validateUserWithSupabase`·`scheduleApi.login`,
  New_MES `src/lib/auth.ts`. 비밀번호를 쓰는 곳: COAD_home 비밀번호 변경 API, 관리자 초기화(`1234`), 신규 등록.

## 단계

| 단계 | 내용 | 노출 감소 | 깨질 수 있는 것 |
|---|---|---|---|
| 1 `20261111120000_login_rpc_password_hash.sql` | `user_credentials`(anon 접근 불가)에 bcrypt 해시, 비밀번호 변경 시 트리거로 동기화, `app_login` RPC, 10회 실패 시 15분 잠금 | 없음 (준비 단계) | 없음. 기존 평문 로그인은 그대로 동작 |
| 앱 배포 | 영업 앱 이 브랜치 → 강제 업데이트 기준 올리기. COAD_home·New_MES도 `app_login`으로 변경 | 없음 | 없음 |
| 2 `20261111120100_users_hide_plaintext_password.sql` | anon/authenticated의 `password` 컬럼 읽기 권한 제거, 평문 지우기, 이후 쓰는 평문은 해시만 남김 | 비밀번호 유출 차단 | 구버전 앱 로그인, `users`를 `select('*')`로 읽는 코드, `1234` 초기 비밀번호 판정 |
| 3 (별도 작업) | `Allow all`·anon 쓰기 정책/권한 제거, 관리자 쓰기는 서버(API/RPC)로 | 계정 탈취·삭제 차단 | 관리자 화면 쓰기 |

1단계 함수 로직은 운영 DB에서 `pg_temp` 임시 테이블과 가짜 데이터로만 검증했다(실제 객체 변경 없음):
평문 폴백 후 해시 생성, 해시 비교, 틀린 비밀번호·없는 아이디 → null, 추가·변경 트리거, 변경 후 옛 비밀번호 거절,
10회 실패 잠금, 응답에 `password` 없음.

## 기존 사용자 영향

- 비밀번호를 바꿀 필요 없음. 1단계 백필이 지금 평문으로 해시를 만든다.
- 앱의 세션 복구는 secure storage의 사용자 JSON만 읽으므로 그대로 유지된다.
- 자동 로그인(저장된 아이디/비밀번호)도 같은 비밀번호로 `app_login`을 부르므로 그대로 동작한다.
