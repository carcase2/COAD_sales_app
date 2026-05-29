// 웹 `TaxInvoiceTab.tsx` · `flutter-tax-invoice-prompt.md` §3 공통 계산.

List<Map<String, dynamic>> taxIssuedIssues(List<Map<String, dynamic>> issues) =>
    issues
        .where((i) => _hasText(i['invoice_image_url']))
        .toList(growable: false);

List<Map<String, dynamic>> taxPendingIssues(
  List<Map<String, dynamic>> issues,
) => issues
    .where((i) => !_hasText(i['invoice_image_url']))
    .toList(growable: false);

double taxIssuedPct(List<Map<String, dynamic>> issues) => taxIssuedIssues(
  issues,
).fold<double>(0, (sum, i) => sum + _toNum(i['percentage']));

double taxRemainingPct(List<Map<String, dynamic>> issues) =>
    (100 - taxIssuedPct(issues)).clamp(0.0, 100.0);

bool taxHasAnyIssued({
  required Map<String, dynamic> invoice,
  required List<Map<String, dynamic>> issues,
}) {
  if (taxIssuedIssues(issues).isNotEmpty) return true;
  final pct = _toNum(invoice['percentage']);
  return _hasText(invoice['invoice_image_url']) && pct >= 100 && issues.isEmpty;
}

bool taxIsFullyIssued({
  required Map<String, dynamic> invoice,
  required List<Map<String, dynamic>> issues,
}) {
  if (issues.isNotEmpty) return taxIssuedPct(issues) >= 100;
  final pct = _toNum(invoice['percentage']);
  return _hasText(invoice['invoice_image_url']) && pct >= 100;
}

bool taxIsLegacyFullyIssuedWithoutIssues(Map<String, dynamic> invoice) {
  final pct = _toNum(invoice['percentage']);
  return _hasText(invoice['invoice_image_url']) && pct >= 100;
}

bool _hasText(dynamic value) => (value ?? '').toString().trim().isNotEmpty;

double _toNum(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '').toString()) ?? 0;
}
