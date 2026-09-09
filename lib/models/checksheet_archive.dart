// MES 아카이브 체크시트(TP1) 검색 결과 모델.

/// 시공후 사진 모델 필터. [code]는 검색(C-1), [label]은 화면(C-1 Standard).
class InstallAfterModelOption {
  const InstallAfterModelOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class ChecksheetAttachment {
  const ChecksheetAttachment({
    required this.id,
    this.originalName,
    this.mime,
    this.fileSize,
    this.r2Key,
    this.uploadedAt,
    required this.mediaPath,
  });

  final String id;
  final String? originalName;
  final String? mime;
  final int? fileSize;
  final String? r2Key;
  final DateTime? uploadedAt;
  /// 서버 상대 경로 `/api/archive/media?id=...`
  final String mediaPath;

  factory ChecksheetAttachment.fromJson(Map<String, dynamic> json) {
    final uploadedRaw = json['uploaded_at'];
    DateTime? uploaded;
    if (uploadedRaw is String && uploadedRaw.isNotEmpty) {
      uploaded = DateTime.tryParse(uploadedRaw);
    }
    return ChecksheetAttachment(
      id: '${json['id'] ?? ''}',
      originalName: json['original_name']?.toString(),
      mime: json['mime']?.toString(),
      fileSize: (json['file_size'] as num?)?.toInt(),
      r2Key: json['r2_key']?.toString(),
      uploadedAt: uploaded,
      mediaPath: '${json['media_path'] ?? ''}',
    );
  }
}

class ChecksheetSite {
  const ChecksheetSite({
    required this.siteKey,
    required this.siteName,
    this.modelName,
    this.regDate,
    this.installCompletedDate,
    this.year,
    this.month,
    required this.checksheetCount,
    this.thumbnailMediaPath,
    required this.attachments,
  });

  final String siteKey;
  final String siteName;
  /// 모델명 (시공후 사진 등)
  final String? modelName;
  /// 등록일 (yyyy-MM-dd)
  final String? regDate;
  /// 시공완료일 (yyyy-MM-dd)
  final String? installCompletedDate;
  final int? year;
  final int? month;
  final int checksheetCount;
  final String? thumbnailMediaPath;
  final List<ChecksheetAttachment> attachments;

  int get photoCount => checksheetCount;

  factory ChecksheetSite.fromJson(Map<String, dynamic> json) {
    final atts = (json['attachments'] as List?)
            ?.whereType<Map>()
            .map((e) => ChecksheetAttachment.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <ChecksheetAttachment>[];
    String? ymd(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return s.substring(0, 10);
      }
      return s;
    }

    return ChecksheetSite(
      siteKey: '${json['site_key'] ?? ''}',
      siteName: '${json['site_name'] ?? ''}',
      modelName: () {
        final m = (json['model_name'] ?? json['modelName'] ?? '').toString().trim();
        return m.isEmpty ? null : m;
      }(),
      regDate: ymd(json['reg_date']),
      installCompletedDate: ymd(
        json['install_completed_date'] ??
            json['install_dt_act'] ??
            json['instal_dt'],
      ),
      year: (json['year'] as num?)?.toInt(),
      month: (json['month'] as num?)?.toInt(),
      checksheetCount: (json['photo_count'] as num?)?.toInt() ??
          (json['checksheet_count'] as num?)?.toInt() ??
          atts.length,
      thumbnailMediaPath: json['thumbnail_media_path']?.toString(),
      attachments: atts,
    );
  }
}

class ChecksheetSearchResult {
  const ChecksheetSearchResult({
    required this.sites,
    required this.totalSites,
    required this.totalAttachments,
    required this.offset,
    required this.limit,
    this.nextOffset,
    this.query,
  });

  final List<ChecksheetSite> sites;
  final int totalSites;
  final int totalAttachments;
  final int offset;
  final int limit;
  final int? nextOffset;
  final String? query;

  bool get hasMore => nextOffset != null;

  factory ChecksheetSearchResult.fromJson(Map<String, dynamic> json) {
    final sites = (json['sites'] as List?)
            ?.whereType<Map>()
            .map((e) => ChecksheetSite.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const <ChecksheetSite>[];
    return ChecksheetSearchResult(
      sites: sites,
      totalSites: (json['total_sites'] as num?)?.toInt() ?? sites.length,
      totalAttachments: (json['total_attachments'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 50,
      nextOffset: (json['next_offset'] as num?)?.toInt(),
      query: json['query']?.toString(),
    );
  }

  static const empty = ChecksheetSearchResult(
    sites: [],
    totalSites: 0,
    totalAttachments: 0,
    offset: 0,
    limit: 50,
  );
}
