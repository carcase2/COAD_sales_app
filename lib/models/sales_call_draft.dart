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
  final String? callStage;
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
      if (originalRegionManager != null && originalRegionManager!.isNotEmpty)
        'original_region_manager': originalRegionManager,
      if (productCategoryId != null) 'product_category_id': productCategoryId,
      if (inquiryMethodId != null) 'inquiry_method_id': inquiryMethodId,
      'status_id': statusId,
      if (createdBy != null) 'created_by': createdBy,
      if (callStage != null) 'call_stage': callStage,
      if (images.isNotEmpty) 'images': images,
    };
  }
}
