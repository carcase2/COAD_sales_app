import 'package:coad_customer_calls/models/sales_call.dart';

extension SalesCallDisplay on SalesCall {
  /// 카드·검색 등에서 보여줄 상담 단계 라벨 (예: `1차`).
  String get displayStageLabel {
    final raw = (callStage ?? '').trim();
    if (RegExp(r'^\d+$').hasMatch(raw)) return '${raw}차';
    if (raw.isEmpty || raw == '0' || raw == '접수') return '1차';
    return raw;
  }

  /// 조인된 `inquiry_methods.name` — 없으면 null.
  String? get displayInquiryMethod {
    final name = inquiryMethodName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }
}
