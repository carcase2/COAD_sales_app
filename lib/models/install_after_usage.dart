class InstallAfterSearchLog {
  const InstallAfterSearchLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    this.modelCode,
    this.modelLabel,
    this.query,
    this.resultCount,
    this.siteName,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String action;
  final String? modelCode;
  final String? modelLabel;
  final String? query;
  final int? resultCount;
  final String? siteName;
  final DateTime createdAt;

  bool get isSearch => action == 'search';

  String get modelDisplay {
    final label = (modelLabel ?? '').trim();
    if (label.isNotEmpty) return label;
    final code = (modelCode ?? '').trim();
    return code.isEmpty ? '모델 없음' : code;
  }

  String get queryDisplay {
    final q = (query ?? '').trim();
    if (q.isNotEmpty) return q;
    final site = (siteName ?? '').trim();
    if (site.isNotEmpty) return site;
    return isSearch ? '현장명 없이 검색' : '—';
  }

  String get actionLabel {
    switch (action) {
      case 'search':
        return '검색';
      case 'view':
        return '열람';
      case 'download':
        return '저장';
      case 'open':
        return '열기';
      default:
        return action;
    }
  }

  factory InstallAfterSearchLog.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString() ?? '';
    return InstallAfterSearchLog(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      userName: (json['user_name'] ?? '').toString().trim(),
      action: (json['action'] ?? 'search').toString().trim().toLowerCase(),
      modelCode: _nz(json['model_code']),
      modelLabel: _nz(json['model_label']),
      query: _nz(json['query']),
      resultCount: (json['result_count'] as num?)?.toInt(),
      siteName: _nz(json['site_name']),
      createdAt: DateTime.tryParse(createdRaw) ?? DateTime.now().toUtc(),
    );
  }
}

String? _nz(Object? v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? null : s;
}

class InstallAfterUserRank {
  const InstallAfterUserRank({
    required this.userId,
    required this.userName,
    required this.searches,
    required this.views,
    required this.downloads,
    required this.opens,
    this.lastAt,
    this.isAdmin = false,
  });

  final String userId;
  final String userName;
  final int searches;
  final int views;
  final int downloads;
  final int opens;
  final DateTime? lastAt;
  final bool isAdmin;

  int get total => searches + views + downloads + opens;
}

class InstallAfterUsageReport {
  const InstallAfterUsageReport({
    required this.ranks,
    required this.logs,
    required this.totalSearches,
    required this.totalViews,
    required this.totalDownloads,
  });

  final List<InstallAfterUserRank> ranks;
  final List<InstallAfterSearchLog> logs;
  final int totalSearches;
  final int totalViews;
  final int totalDownloads;

  int get userCount => ranks.length;

  InstallAfterUserRank? get topSearcher =>
      ranks.isEmpty ? null : ranks.first;
}

/// 기간 안 로그를 사용자별 검색 횟수 순으로 집계.
InstallAfterUsageReport buildInstallAfterUsageReport(
  List<InstallAfterSearchLog> logs, {
  Set<String> adminIds = const {},
}) {
  final byUser = <String, _RankAcc>{};
  var searches = 0;
  var views = 0;
  var downloads = 0;

  for (final log in logs) {
    if (log.userId.isEmpty) continue;
    switch (log.action) {
      case 'search':
        searches++;
      case 'view':
        views++;
      case 'download':
        downloads++;
      default:
        break;
    }
    final acc = byUser.putIfAbsent(
      log.userId,
      () => _RankAcc(name: log.userName),
    );
    if (acc.name.trim().isEmpty && log.userName.trim().isNotEmpty) {
      acc.name = log.userName;
    }
    switch (log.action) {
      case 'search':
        acc.searches++;
      case 'view':
        acc.views++;
      case 'download':
        acc.downloads++;
      case 'open':
        acc.opens++;
    }
    if (acc.lastAt == null || log.createdAt.isAfter(acc.lastAt!)) {
      acc.lastAt = log.createdAt;
    }
  }

  final ranks = byUser.entries
      .map(
        (e) => InstallAfterUserRank(
          userId: e.key,
          userName: e.value.name.trim().isEmpty ? e.key : e.value.name.trim(),
          searches: e.value.searches,
          views: e.value.views,
          downloads: e.value.downloads,
          opens: e.value.opens,
          lastAt: e.value.lastAt,
          isAdmin: adminIds.contains(e.key),
        ),
      )
      .toList()
    ..sort((a, b) {
      final bySearch = b.searches.compareTo(a.searches);
      if (bySearch != 0) return bySearch;
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return a.userName.compareTo(b.userName);
    });

  final sortedLogs = List<InstallAfterSearchLog>.from(logs)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return InstallAfterUsageReport(
    ranks: ranks,
    logs: sortedLogs,
    totalSearches: searches,
    totalViews: views,
    totalDownloads: downloads,
  );
}

class _RankAcc {
  _RankAcc({required this.name});

  String name;
  int searches = 0;
  int views = 0;
  int downloads = 0;
  int opens = 0;
  DateTime? lastAt;
}
