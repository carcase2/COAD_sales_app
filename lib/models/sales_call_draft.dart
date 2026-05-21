class SalesCallDraft {
  const SalesCallDraft({
    required this.customerName,
    required this.customerPhone,
    required this.inquiryContent,
    required this.regionId,
    required this.regionSido,
    required this.regionName,
    required this.regionManager,
    required this.assignedTo,
    this.originalRegionManager,
    this.productCategoryId,
    this.inquiryMethodId,
    this.statusId = 1,
    this.createdBy,
    this.callStage,
    this.images = const <String>[],
  });

  final String customerName;
  final String customerPhone;
  final String inquiryContent;
  final String regionId;
  final String regionSido;
  final String regionName;
  final String regionManager;
  final String assignedTo;
  final String? originalRegionManager;
  final String? productCategoryId;
  final String? inquiryMethodId;
  final int statusId;
  final String? createdBy;
  /// DB `sales_calls.call_stage` — 정수(0=미통화, 1+=상담 단계)
  final Object? callStage;
  final List<String> images;

  Map<String, dynamic> toInsertJson() {
    return {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'inquiry_content': inquiryContent,
      'region_id': regionId,
      'region_sido': regionSido,
      'region_name': regionName,
      'region_manager': regionManager,
      'assigned_to': assignedTo,
      // original_region_manager: DB 컬럼 없음 — 임시변경 시 inquiry_content에 메모로 남김
      if (productCategoryId != null) 'product_category_id': productCategoryId,
      if (inquiryMethodId != null) 'inquiry_method_id': inquiryMethodId,
      'status_id': statusId,
      if (createdBy != null) 'created_by': createdBy,
      if (callStage != null) 'call_stage': callStage,
      if (images.isNotEmpty) 'images': images,
    };
  }
}
