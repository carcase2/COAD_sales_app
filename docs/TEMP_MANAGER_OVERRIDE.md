# COAD — 지역 담당자 임시 변경 (Temp Manager Override)

웹(Next.js) · Flutter 앱 **동일 규칙** (2026-05 통일).

## 배경

특정 지역 담당을 기간 동안 다른 사람으로 **표시·접수**하고, 기간이 끝나면:

1. **지역 현재 담당** → 원담당(`regions.manager`) 표시
2. **적용 기간 중 임시 담당 명의 접수 건** → `original_manager`로 **DB 자동 원복**

- `regions.manager` 컬럼은 변경하지 않음 (런타임 오버레이).
- `temp_manager_overrides` 레코드는 만료 후에도 삭제되지 않음.

---

## Supabase: `temp_manager_overrides`

| 컬럼 | 설명 |
|------|------|
| region_name | `regions.region` 문자열 매칭 |
| original_manager | 등록 시점 원담당 스냅샷 |
| temp_manager | 임시 담당자 |
| start_date / end_date | KST, **종료일 당일 포함** |
| is_active | false면 미적용 |

관리: **웹** 시스템 → 관리자 → 지역담당자 관리.

---

## Flutter 구현 파일

| 용도 | 위치 |
|------|------|
| 기간·원복·목록 오버레이 | `lib/data/temp_manager_logic.dart` |
| regions 합성 | `SalesCallsRepository.buildEffectiveRegions()` |
| 만료 DB 원복 | `SalesCallsRepository.revertExpiredTempManagerCalls()` |
| 목록/상세 fetch 시 | `fetchCalls` · `fetchCallById` · `searchCalls` |
| Provider | `tempManagerOverridesProvider` (fetch 전 revert) |
| 접수 저장 | `SalesCallCreateScreen` — `assigned_to` = **effective(임시)** |
| 목록 담당 칩 | `displayAssigneeForCall()` (= 웹 `applyCallOverrides`) |
| 테스트 | `test/temp_manager_overrides_test.dart` |

---

## 기간 중

| 항목 | 동작 |
|------|------|
| 지역 선택 | `effectiveRegions` → **임시 담당** |
| 접수 저장 | `assigned_to` = **임시 담당** |
| 목록 표시 | `applyCallDisplayOverrides` — DB가 원담당이어도 기간 중 **임시로 표시** |
| 푸시 | `notify-new-call` — 대행 기간 중 **임시 담당만** (Edge Function) |

---

## 기간 만료 후 (종료일 다음 날, KST)

| 항목 | 동작 |
|------|------|
| 지역 선택 | **원담당** |
| 접수 건 DB | `revertExpiredTempManagerCalls()` — 기간 내·임시 명의 건 → `original_manager` |
| 원복 API | `BASE_URL` 있으면 `POST /api/temp-manager/revert-expired`, 없으면 Supabase 직접 UPDATE |
| 목록 표시 | 오버레이 없음 + DB 원담당 |

원복 대상: `assigned_to`가 `temp_manager`이고, 접수일이 override 기간 안인 건.

---

## 테스트

```bash
flutter test test/temp_manager_overrides_test.dart
```

웹 프롬프트: COAD_home `docs/flutter-temp-manager-prompt.md`
