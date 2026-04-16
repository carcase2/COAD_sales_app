# Flutter 이식 프롬프트: 발급요청 탭

## 역할
- 상위 메인 탭이 세금계산서/이행증권일 때 하위 탭 `발급요청`은 아직 발급 이미지가 없는 대기 건만 노출한다.
- 본 스펙은 세금계산서(`tax_invoices`, `tax_invoice_issues`)와 이행증권(`performance_bonds`, `performance_bond_issues`)에만 적용한다.

## 테이블
- 세금계산서
  - 마스터: `tax_invoices`
  - 이슈: `tax_invoice_issues` (`tax_invoice_id -> tax_invoices.id`)
- 이행증권
  - 마스터: `performance_bonds`
  - 이슈: `performance_bond_issues` (`performance_bond_id -> performance_bonds.id`)

## 발급 완료 판정
- 세금계산서
  - 이슈 행에서 `invoice_image_url`이 있으면 해당 이슈는 발급됨
  - 이슈가 없는 레거시는 마스터 `invoice_image_url` + `percentage >= 100`이면 완료로 간주
- 이행증권
  - 이슈 행에서 `bond_image_url`이 있으면 발급됨
  - 또는 마스터 `bond_image_url`이 있으면 발급됨으로 간주

## 발급요청 탭 구성 규칙
- 세금계산서
  1. 해당 인보이스 이슈 중 하나라도 `invoice_image_url`이 있으면 전체 제외
  2. 미발급 이슈(`invoice_image_url` 없음)만 있으면 이슈 개수만큼 행 생성
  3. 이슈가 없고 레거시 완료 조건이면 제외
  4. 이슈가 없고 `status = 'pending'`이면 `{invoice, issue: null}` 1행
- 이행증권
  1. `performance_bonds`에서 `status in ('pending','draft')` 대상 조회
  2. 이슈 중 `bond_image_url`이 있거나 마스터 `bond_image_url` 있으면 제외
  3. 이슈 없으면 `{bond, issue: null}` 1행
  4. 이슈 있으면 `bond_image_url` 없는 이슈마다 1행

## 목록 모델
- 세금계산서: `List<{ invoice: TaxInvoice, issue: TaxInvoiceIssue | null }>`
- 이행증권: `List<{ bond: PerformanceBond, issue: PerformanceBondIssue | null }>`

## 배지 카운트와 탭 로직 차이
- 배지 카운트는 `pending`만 대상으로 집계하는 구현이 존재할 수 있다.
- 탭 목록은 전체 스캔 후 클라이언트 필터를 사용할 수 있어 집계 기준이 다를 수 있다.
- Flutter에서는 배지/탭 기준을 하나로 통일할지 사전에 결정한다.
- 현재 Flutter 구현은 `탭(all-scan 필터) 결과`를 그대로 배지에 재사용하는 단일 기준을 사용한다.

## Flutter 구현 체크리스트
- 이슈 단위로 리스트가 펼쳐질 수 있도록 설계
- `is_urgent`(세금계산서) 배지 표시
- `request_image_url`(이행증권 요청 이미지)과 `bond_image_url`(발급 이미지) 구분
- 검색/필터 전략: 클라이언트 필터 또는 서버 집계 API 중 선택
- 스토리지 업로드 후 URL을 이슈/마스터에 저장
- RLS/권한 정책, `created_by` 담당자 필터 반영

## 스토리지 참고
- 세금계산서 이미지 버킷: `tax-invoices` (웹 구현과 동일 기준 사용)
