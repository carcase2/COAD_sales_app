/// issue_request API 표시용 한글 라벨 (DB/API 필드값은 변경하지 않음).
class IssueRequestLabels {
  IssueRequestLabels._();

  static const requestTypes = <String, String>{
    'tax_invoice': '세금계산서',
    'performance_bond': '이행증권',
  };

  static String requestTypeLabel(String raw) => requestTypes[raw.trim()] ?? raw;

  static String statusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending':
        return '대기';
      case 'approved':
        return '승인';
      case 'rejected':
        return '반려';
      default:
        return raw;
    }
  }
}
