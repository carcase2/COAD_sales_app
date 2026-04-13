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
      history = historyRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      
      // 최신 이력이 먼저 나오도록 call_stage(정수형 선호) 기준 내림차순 정렬 (3, 2, 1 순서)
      history.sort((a, b) {
        // DB 스키마에 맞춰 consultation_content가 있는지 확인 (디버깅용으로도 유용)
        
        final stageA = a['call_stage'] is int ? a['call_stage'] : int.tryParse(a['call_stage']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
        final stageB = b['call_stage'] is int ? b['call_stage'] : int.tryParse(b['call_stage']?.toString()?.replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
        
        if (stageB != stageA) {
          return stageB.compareTo(stageA);
        }
        
        // 차수가 같으면 created_at 기준으로 내림차순
        final timeA = a['created_at']?.toString() ?? '';
        final timeB = b['created_at']?.toString() ?? '';
        return timeB.compareTo(timeA);
      });
    }

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
      statusId: _int(json, const ['status_id', 'statusId']),
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
      statusLabel: _nestedName(json, const [
        'call_statuses',
        'call_status',
        'callStatus',
      ]),
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
      if (regionManager != null) 'region_manager': regionManager,
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
  if (direct != null) return direct;
  final nested = _nestedName(json, const ['regions', 'region']);
  if (nested != null) return nested;
  final sido = _pick(json, const ['region_sido', 'regionSido']);
  final name = _pick(json, const ['region_name', 'regionName']);
  if (sido != null && name != null) return '$sido $name';
  return sido ?? name;
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
