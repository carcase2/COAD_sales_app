class GosuCallHistory {
  const GosuCallHistory({
    required this.id,
    required this.gosuSalesCallId,
    required this.callDate,
    required this.callTime,
    required this.callStage,
    required this.consultationContent,
    this.nextScheduledDate,
    this.followResult = '진행중',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String gosuSalesCallId;
  final String callDate;
  final String callTime;
  final int callStage;
  final String consultationContent;
  final String? nextScheduledDate;
  final String followResult;
  final String? createdBy;
  final String? createdAt;

  factory GosuCallHistory.fromJson(Map<String, dynamic> json) {
    return GosuCallHistory(
      id: _pick(json, const ['id']) ?? '',
      gosuSalesCallId:
          _pick(json, const ['gosu_sales_call_id', 'gosuSalesCallId']) ?? '',
      callDate: _pick(json, const ['call_date', 'callDate']) ?? '',
      callTime: _pick(json, const ['call_time', 'callTime']) ?? '',
      callStage: _int(json, const ['call_stage', 'callStage']) ?? 0,
      consultationContent:
          _pick(json, const ['consultation_content', 'consultationContent']) ??
          '',
      nextScheduledDate: _pick(json, const [
        'next_scheduled_date',
        'nextScheduledDate',
      ]),
      followResult:
          _pick(json, const ['follow_result', 'followResult']) ?? '진행중',
      createdBy: _pick(json, const ['created_by', 'createdBy']),
      createdAt: _pick(json, const ['created_at', 'createdAt']),
    );
  }
}

class GosuSalesCall {
  const GosuSalesCall({
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
    this.images = const [],
    this.regionSido,
    this.regionName,
    this.regionManager,
    this.regionBranchType,
    this.regionLabel,
    this.productCategoryName,
    this.inquiryMethodName,
    this.statusName,
    this.followUp,
    this.followUpContent,
    this.callStage = 0,
    this.nextScheduledDate,
    this.source,
    this.createdAt,
    this.updatedAt,
    this.callHistory = const [],
  });

  final String id;
  final String? callDate;
  final String? callTime;
  final String? customerName;
  final String? customerPhone;
  final String? inquiryContent;
  final int? productCategoryId;
  final int? inquiryMethodId;
  final int? regionId;
  final int? statusId;
  final String? assignedTo;
  final String? createdBy;
  final List<String> images;
  final String? regionSido;
  final String? regionName;
  final String? regionManager;
  final String? regionBranchType;
  final String? regionLabel;
  final String? productCategoryName;
  final String? inquiryMethodName;
  final String? statusName;
  final String? followUp;
  final String? followUpContent;
  final int callStage;
  final String? nextScheduledDate;
  final String? source;
  final String? createdAt;
  final String? updatedAt;
  final List<GosuCallHistory> callHistory;

  String get displayName {
    final n = customerName?.trim();
    if (n == null || n.isEmpty) return '상호없음';
    return n;
  }

  String get displayPhone => customerPhone?.trim() ?? '';

  String get displayRegion {
    final sido = regionSido?.trim() ?? '';
    final name = regionName?.trim() ?? '';
    if (sido.isNotEmpty && name.isNotEmpty && name != sido) {
      return '[$sido]$name';
    }
    if (sido.isNotEmpty) return '[$sido]';
    if (name.isNotEmpty) return name;
    final label = regionLabel?.replaceAll(':', '').trim();
    if (label != null && label.isNotEmpty) return label;
    return '지역 미지정';
  }

  String get followCalendarDateKey {
    final raw = nextScheduledDate?.trim() ?? '';
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  factory GosuSalesCall.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['call_history'] ?? json['callHistory'];
    var history = <GosuCallHistory>[];
    if (historyRaw is List) {
      history = historyRaw
          .whereType<Map>()
          .map((e) => GosuCallHistory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      history.sort((a, b) {
        final stage = a.callStage.compareTo(b.callStage);
        if (stage != 0) return stage;
        return a.callDate.compareTo(b.callDate);
      });
    }

    return GosuSalesCall(
      id: _pick(json, const ['id']) ?? '',
      callDate: _pick(json, const ['call_date', 'callDate']),
      callTime: _pick(json, const ['call_time', 'callTime']),
      customerName: _pick(json, const ['customer_name', 'customerName']),
      customerPhone: _pick(json, const ['customer_phone', 'customerPhone']),
      inquiryContent: _pick(json, const ['inquiry_content', 'inquiryContent']),
      productCategoryId: _int(json, const [
        'product_category_id',
        'productCategoryId',
      ]),
      inquiryMethodId: _int(json, const [
        'inquiry_method_id',
        'inquiryMethodId',
      ]),
      regionId: _int(json, const ['region_id', 'regionId']),
      statusId: _int(json, const ['status_id', 'statusId']),
      assignedTo: _pick(json, const ['assigned_to', 'assignedTo']),
      createdBy: _pick(json, const ['created_by', 'createdBy']),
      images: _parseImageUrls(json['images']),
      regionSido: _pick(json, const ['region_sido', 'regionSido']),
      regionName: _pick(json, const ['region_name', 'regionName']),
      regionManager: _pick(json, const ['region_manager', 'regionManager']),
      regionBranchType: _pick(json, const [
        'region_branch_type',
        'regionBranchType',
      ]),
      regionLabel: _pick(json, const ['region_label', 'regionLabel']),
      productCategoryName:
          _pick(json, const ['product_category_name', 'productCategoryName']) ??
          _nestedName(json, const ['product_categories', 'product_category']),
      inquiryMethodName:
          _pick(json, const ['inquiry_method_name', 'inquiryMethodName']) ??
          _nestedName(json, const ['inquiry_methods', 'inquiry_method']),
      statusName: _pick(json, const ['status_name', 'statusName']),
      followUp: _pick(json, const ['follow_up', 'followUp']),
      followUpContent: _pick(json, const [
        'follow_up_content',
        'followUpContent',
      ]),
      callStage: _int(json, const ['call_stage', 'callStage']) ?? 0,
      nextScheduledDate: _pick(json, const [
        'next_scheduled_date',
        'nextScheduledDate',
      ]),
      source: _pick(json, const ['source']),
      createdAt: _pick(json, const ['created_at', 'createdAt']),
      updatedAt: _pick(json, const ['updated_at', 'updatedAt']),
      callHistory: history,
    );
  }

  GosuSalesCall copyWith({
    List<GosuCallHistory>? callHistory,
    List<String>? images,
    String? followUp,
    String? followUpContent,
    int? callStage,
    String? nextScheduledDate,
    String? customerName,
    String? customerPhone,
    String? inquiryContent,
    String? productCategoryName,
    String? inquiryMethodName,
    String? assignedTo,
  }) {
    return GosuSalesCall(
      id: id,
      callDate: callDate,
      callTime: callTime,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      inquiryContent: inquiryContent ?? this.inquiryContent,
      productCategoryId: productCategoryId,
      inquiryMethodId: inquiryMethodId,
      regionId: regionId,
      statusId: statusId,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy,
      images: images ?? this.images,
      regionSido: regionSido,
      regionName: regionName,
      regionManager: regionManager,
      regionBranchType: regionBranchType,
      regionLabel: regionLabel,
      productCategoryName: productCategoryName ?? this.productCategoryName,
      inquiryMethodName: inquiryMethodName ?? this.inquiryMethodName,
      statusName: statusName,
      followUp: followUp ?? this.followUp,
      followUpContent: followUpContent ?? this.followUpContent,
      callStage: callStage ?? this.callStage,
      nextScheduledDate: nextScheduledDate ?? this.nextScheduledDate,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
      callHistory: callHistory ?? this.callHistory,
    );
  }
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
    if (v is String) return int.tryParse(v);
  }
  return null;
}

String? _nestedName(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is Map) {
      final n = v['name'] ?? v['label'];
      if (n != null) return n.toString();
    }
  }
  return null;
}

List<String> _parseImageUrls(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e.toString())
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }
  return const [];
}
