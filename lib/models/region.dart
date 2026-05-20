class Region {
  const Region({
    required this.id,
    required this.sido,
    required this.region,
    required this.manager,
    this.branchType,
    this.userId,
    this.originalManager,
    this.effectiveManager,
    this.isManagerOverridden = false,
  });

  final String id;
  final String sido;
  final String region;
  final String manager;
  final String? branchType;
  final String? userId;

  /// 원본 지역 담당자(오버라이드 UI/통계용).
  final String? originalManager;

  /// 임시 오버라이드 적용 후 담당자.
  final String? effectiveManager;
  final bool isManagerOverridden;

  String get resolvedManager => (effectiveManager ?? manager).trim();
  String get resolvedOriginalManager => (originalManager ?? manager).trim();

  Region copyWith({
    String? id,
    String? sido,
    String? region,
    String? manager,
    String? branchType,
    String? userId,
    String? originalManager,
    String? effectiveManager,
    bool? isManagerOverridden,
  }) {
    return Region(
      id: id ?? this.id,
      sido: sido ?? this.sido,
      region: region ?? this.region,
      manager: manager ?? this.manager,
      branchType: branchType ?? this.branchType,
      userId: userId ?? this.userId,
      originalManager: originalManager ?? this.originalManager,
      effectiveManager: effectiveManager ?? this.effectiveManager,
      isManagerOverridden: isManagerOverridden ?? this.isManagerOverridden,
    );
  }

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: (json['id'] ?? '').toString(),
      sido: (json['sido'] ?? '').toString(),
      region: (json['region'] ?? '').toString(),
      manager: (json['manager'] ?? '').toString(),
      branchType: json['branch_type']?.toString(),
      userId: json['user_id']?.toString(),
      originalManager: json['original_manager']?.toString(),
      effectiveManager: json['effective_manager']?.toString(),
      isManagerOverridden: json['is_overridden'] == true ||
          json['is_overridden']?.toString() == 'true',
    );
  }

  Map<String, dynamic> toMasterRowJson() {
    return {
      'id': id,
      'sido': sido,
      'region': region,
      'manager': resolvedManager,
      'branch_type': branchType,
      'user_id': userId,
      'original_manager': resolvedOriginalManager,
      'effective_manager': resolvedManager,
      'is_overridden': isManagerOverridden,
      // 드롭다운 표기용 이름(검색성 향상)
      'name': '$sido $region ($resolvedManager)',
    };
  }
}
