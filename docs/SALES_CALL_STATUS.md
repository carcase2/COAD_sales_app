# 고객전화 상담 결과 · 팔로우 (Flutter)

웹·DB와 동일 규칙. 상세 스펙: COAD_home `docs/flutter-sales-call-status-prompt.md`

## 구현

| 항목 | 파일 |
|------|------|
| 검증·history/main payload | `lib/data/sales_call_consultation.dart` |
| 상담 저장 (history → main) | `SalesCallsRepository.saveConsultationRound` |
| 접수 | `sales_call_create_screen.dart` — 미결정+`call_stage=0`, 단순문의+`4`/`1` |
| N차 상담 | `sales_call_detail_screen.dart` — 검증·미수주 사유·예정일 |
| 미통화 / 팔로우 | `sales_call.dart` `isMissed`, `fetchCalls` `incompleteOnly` |

## 상담 저장 검증

- **미결정(1):** `next_scheduled_date` 필수
- **미수주(2):** `unsuccessful_reason` 필수, 상담내용 선택
- **수주(3):** 상담내용 선택
- **기타·단순·설계:** 예정일 없음 (`next_scheduled_date` = null)

## 팔로우 (`next_scheduled_date`)

- 미결정만 대상. `status_id` **2·3·4·5·6**(+레거시 22) 제외 (미수주·수주·단순문의·설계문의·기타)
- 예정일 없으면 달력·금일팔로우 제외

## 테스트

```bash
flutter test test/sales_call_consultation_test.dart
```
