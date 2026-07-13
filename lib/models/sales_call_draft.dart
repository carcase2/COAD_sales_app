import 'package:coad_customer_calls/core/utils/date_seoul.dart';

class SalesCallDraft {
  const SalesCallDraft({
    required this.customerName,
    required this.customerPhone,
    required this.inquiryContent,
    required this.regionId,
    required this.regionSido,
    required this.regionName,
    required this.assignedTo,
    this.productCategoryId,
    this.inquiryMethodId,
    this.statusId = 1,
    this.createdBy,
    this.callStage,
    this.images = const <String>[],
    this.callDateYmd,
    this.callTimeHms,
  });

  final String customerName;
  final String customerPhone;
  final String inquiryContent;
  final String regionId;
  final String regionSido;
  final String regionName;
  final String assignedTo;
  final String? productCategoryId;
  final String? inquiryMethodId;
  final int statusId;
  final String? createdBy;
  /// DB `sales_calls.call_stage` — 정수(0=미통화, 1+=상담 단계)
  final Object? callStage;
  final List<String> images;
  /// 서울 현지 `yyyy-MM-dd`. null이면 [toInsertJson]에서 현재 시각으로 채움.
  final String? callDateYmd;
  /// 서울 현지 `HH:mm:ss`. null이면 [toInsertJson]에서 현재 시각으로 채움.
  final String? callTimeHms;

  Map<String, dynamic> toInsertJson() {
    final parts = seoulNowCallDateTimeParts();
    return {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'inquiry_content': inquiryContent,
      'region_id': regionId,
      'region_sido': regionSido,
      'region_name': regionName,
      'assigned_to': assignedTo,
      // DB UTC 기본값에 의존하지 않음 — 웹과 동일하게 KST 벽시계로 저장
      'call_date': (callDateYmd != null && callDateYmd!.trim().isNotEmpty)
          ? callDateYmd!.trim()
          : parts.ymd,
      'call_time': (callTimeHms != null && callTimeHms!.trim().isNotEmpty)
          ? callTimeHms!.trim()
          : parts.hms,
      if (productCategoryId != null) 'product_category_id': productCategoryId,
      if (inquiryMethodId != null) 'inquiry_method_id': inquiryMethodId,
      'status_id': statusId,
      if (createdBy != null) 'created_by': createdBy,
      if (callStage != null) 'call_stage': callStage,
      if (images.isNotEmpty) 'images': images,
    };
  }
}
