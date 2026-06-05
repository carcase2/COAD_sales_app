import 'package:coad_customer_calls/data/sales_call_consultation.dart';

class SalesCall {
  SalesCall({
    required this.id,
    this.callDate,
    this.callTime,
    this.customerName,
    this.customerPhone,
    this.inquiryContent,
    this.productCategoryId,
    this.inquiryMethodId,
    this.regionId,
    this.statusId,
    this.assignedTo,
    this.createdBy,
    this.callStage,
    this.nextScheduledDate,
    this.regionSido,
    this.regionName,
    this.regionManager,
    this.regionBranchType,
    this.createdAt,
    this.updatedAt,
    this.productCategoryName,
    this.inquiryMethodName,
    this.regionLabel,
    this.statusLabel,
    this.callHistory = const [],
    this.images = const [],
  });

  final String id;
  final String? callDate;
  final String? callTime;
  final String? customerName;
  final String? customerPhone;
  final String? inquiryContent;
  final String? productCategoryId;
  final String? inquiryMethodId;
  final String? regionId;
  final int? statusId;
  final String? assignedTo;
  final String? createdBy;
  final String? callStage;
  final String? nextScheduledDate;
  final String? regionSido;
  final String? regionName;
  final String? regionManager;
  final String? regionBranchType;
  final String? createdAt;
  final String? updatedAt;
  final String? productCategoryName;
  final String? inquiryMethodName;
  final String? regionLabel;
  final String? statusLabel;
  final List<Map<String, dynamic>> callHistory;
  /// 메인 Supabase `sales_calls.images` (`text[]`) — 첨부마다 B2 공개 HTTPS URL 문자열.
  ///
  /// 웹 고객전화 주 흐름과 동일. 레거시 `sales_call_images` 행과의 동기는 서버/웹에서 처리할 수 있음.
  final List<String> images;

  factory SalesCall.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['call_history'] ?? json['callHistory'];
    List<Map<String, dynamic>> history = [];
    if (historyRaw is List) {
      history = orderCallHistoryForDisplay(
        historyRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    }

    final statusId = _int(json, const ['status_id', 'statusId']);
    final nestedStatusLabel = _nestedName(json, const [
      'call_statuses',
      'call_status',
      'callStatus',
    ]);

    return SalesCall(
      id: _pick(json, const ['id']) ?? '',
      callDate: _pick(json, const ['call_date', 'callDate']),
      callTime: _pick(json, const ['call_time', 'callTime']),
      customerName: _pick(json, const ['customer_name', 'customerName']),
      customerPhone: _pick(json, const ['customer_phone', 'customerPhone']),
      inquiryContent: _pick(json, const ['inquiry_content', 'inquiryContent']),
      productCategoryId: _pick(json, const ['product_category_id', 'productCategoryId']),
      inquiryMethodId: _pick(json, const ['inquiry_method_id', 'inquiryMethodId']),
      regionId: _pick(json, const ['region_id', 'regionId']),
      statusId: statusId,
      assignedTo: _pick(json, const ['assigned_to', 'assignedTo']),
      createdBy: _pick(json, const ['created_by', 'createdBy']),
      callStage: _pick(json, const ['call_stage', 'callStage']),
      nextScheduledDate: _pick(json, const ['next_scheduled_date', 'nextScheduledDate']),
      regionSido: _pick(json, const ['region_sido', 'regionSido']),
      regionName: _pick(json, const ['region_name', 'regionName']),
      regionManager: _pick(json, const ['region_manager', 'regionManager']),
      regionBranchType: _pick(json, const ['region_branch_type', 'regionBranchType']),
      createdAt: _pick(json, const ['created_at', 'createdAt']),
      updatedAt: _pick(json, const ['updated_at', 'updatedAt']),
      productCategoryName: _nestedName(json, const [
        'product_categories',
        'product_category',
        'productCategory',
      ]),
      inquiryMethodName: _nestedName(json, const [
        'inquiry_methods',
        'inquiry_method',
        'inquiryMethod',
      ]),
      regionLabel: _regionLabel(json),
      statusLabel: statusId != null
          ? callStatusNameFromId(statusId)
          : nestedStatusLabel,
      callHistory: history,
      images: _parseImageUrls(json['images']),
    );
  }

  bool get isMissed {
    // 웹 기준: (단계가 0 또는 null) 이고 (상황이 단순문의가 아닌 건)
    final s = callStage?.trim();
    final isInitialStage = s == null || s == '' || s == '0' || s == '접수';
    final isNotSimpleInquiry = statusId != 4;
    return isInitialStage && isNotSimpleInquiry;
  }

  /// 날짜 팔로우·캘린더 집계 기준: `next_scheduled_date`(다음 회차 예정일)의 yyyy-MM-dd.
  /// 없으면 null — 접수일(`call_date`)로 대체하지 않음.
  String? get followCalendarDateKey {
    final raw = nextScheduledDate?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.length >= 10) {
      final head = raw.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(head)) return head;
    }
    final dt = DateTime.tryParse(raw);
    if (dt != null) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  /// 상단 카드·현재 성과용 `status_id`.
  /// `sales_calls.status_id`가 종료 상태면 우선하고, 아니면 최신 이력·라벨을 참고.
  int? effectiveStatusId({List<Map<String, dynamic>>? orderedHistory}) {
    if (isTerminalConsultationStatus(statusId)) return statusId;

    final history = orderedHistory ?? orderCallHistoryForDisplay(callHistory);
    if (history.isNotEmpty) {
      final histId = statusIdFromHistoryMap(history.first);
      if (histId != null) return histId;
    }
    if (statusId != null) return statusId;
    return statusIdFromStatusName(statusLabel);
  }

  bool canEnterFurtherConsultationRound({List<Map<String, dynamic>>? orderedHistory}) =>
      canEnterFurtherConsultation(effectiveStatusId(orderedHistory: orderedHistory));

  /// 미수주일 때 최신 이력의 `unsuccessful_reason`.
  String? effectiveUnsuccessfulReason({List<Map<String, dynamic>>? orderedHistory}) {
    if (effectiveStatusId(orderedHistory: orderedHistory) != CallStatusIds.lost) {
      return null;
    }
    final history = orderedHistory ?? orderCallHistoryForDisplay(callHistory);
    for (final h in history) {
      if (statusIdFromHistoryMap(h) != CallStatusIds.lost) continue;
      final reason = unsuccessfulReasonFromHistoryMap(h);
      if (reason != null) return reason;
    }
    return null;
  }

  /// 상단 카드·현재 성과용. 최신 `call_history` → `status_id` 순.
  String effectiveStatusLabel({List<Map<String, dynamic>>? orderedHistory}) {
    final history = orderedHistory ?? orderCallHistoryForDisplay(callHistory);
    final effectiveId = effectiveStatusId(orderedHistory: orderedHistory);
    if (effectiveId != null) return callStatusNameFromId(effectiveId);
    if (history.isNotEmpty) {
      final text = (history.first['status'] ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    if (statusId != null) return callStatusNameFromId(statusId);
    final label = statusLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return '미확인';
  }

  Map<String, dynamic> toUpdateBody() {
    return {
      'customer_phone': customerPhone,
      'customer_name': customerName,
      'inquiry_content': inquiryContent,
      if (productCategoryId != null) 'product_category_id': productCategoryId,
      if (inquiryMethodId != null) 'inquiry_method_id': inquiryMethodId,
      if (regionId != null) 'region_id': regionId,
      if (statusId != null) 'status_id': statusId,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (callStage != null) 'call_stage': callStage,
      if (nextScheduledDate != null) 'next_scheduled_date': nextScheduledDate,
      if (regionSido != null) 'region_sido': regionSido,
      if (regionName != null) 'region_name': regionName,
      if (regionBranchType != null) 'region_branch_type': regionBranchType,
      'images': images,
    };
  }
}

List<String> _parseImageUrls(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
  }
  return [];
}

String? _pick(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) return v.toString();
  }
  return null;
}

int? _int(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
  }
  return null;
}

String? _nestedName(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final n = m['name'] ?? m['label'];
      if (n != null) return n.toString();
    }
  }
  return null;
}

String? _regionLabel(Map<String, dynamic> json) {
  final direct = _pick(json, const ['region_display', 'region_label', 'regionLabel']);
  final s = _pick(json, const ['region_sido', 'regionSido'])?.trim() ?? '';
  final r = _pick(json, const ['region_name', 'region_region', 'regionName', 'regionRegion'])?.trim() ?? '';
  final m = (_pick(json, const ['assigned_to', 'assignedTo']) ??
          _pick(json, const ['region_manager', 'regionManager']))
      ?.trim() ??
      '';
  final b = _pick(json, const ['region_branch_type', 'regionBranchType'])?.trim() ?? '';

  String label = s.isNotEmpty ? '[$s] ' : '';
  if (r.isNotEmpty && r != s) {
    label += r;
  } else if (r.isEmpty && s.isEmpty) {
    return null; 
  }

  if (m.isNotEmpty || b.isNotEmpty) {
    label += ' ($m${m.isNotEmpty && b.isNotEmpty ? ' - ' : ''}$b)';
  }
  return label.isEmpty ? null : label;
}

List<SalesCall> parseSalesCallList(dynamic decoded) {
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((e) => SalesCall.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  if (decoded is Map<String, dynamic>) {
    for (final key in const [
      'sales_calls',
      'salesCalls',
      'data',
      'items',
      'calls',
      'rows',
    ]) {
      final v = decoded[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => SalesCall.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
  }
  return [];
}
