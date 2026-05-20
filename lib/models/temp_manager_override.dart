class TempManagerOverride {
  const TempManagerOverride({
    required this.id,
    required this.regionName,
    required this.originalManager,
    required this.tempManager,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String regionName;
  final String originalManager;
  final String tempManager;
  final String? startDate; // yyyy-MM-dd
  final String? endDate; // yyyy-MM-dd
  final String? memo;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  factory TempManagerOverride.fromJson(Map<String, dynamic> json) {
    return TempManagerOverride(
      id: (json['id'] ?? '').toString(),
      regionName: (json['region_name'] ?? '').toString().trim(),
      originalManager: (json['original_manager'] ?? '').toString().trim(),
      tempManager: (json['temp_manager'] ?? '').toString().trim(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      memo: json['memo']?.toString(),
      isActive: json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
