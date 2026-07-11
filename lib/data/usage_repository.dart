import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/app_usage_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsageRepository {
  UsageRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// [startYmd]~[endYmd](포함) 구간의 앱 사용 기록이 있는 사용자만 합산한다.
  /// [days]만 주면 오늘 기준 최근 N일(오늘 포함)로 조회한다.
  Future<List<AppUsageSummary>> fetchSummaries({
    int days = 7,
    String? startYmd,
    String? endYmd,
  }) async {
    final resolvedEnd = endYmd ?? todayYmdSeoul();
    final resolvedStart =
        startYmd ?? addDaysToYmd(resolvedEnd, -(days - 1).clamp(0, 366));

    final usageRes = await _client
        .from('app_usage_daily')
        .select(
          'user_id, user_name, usage_date, app_opens, tab_counts, updated_at',
        )
        .gte('usage_date', resolvedStart)
        .lte('usage_date', resolvedEnd)
        .order('usage_date', ascending: false);

    final usageByUser = _aggregateUsage(
      List<Map<String, dynamic>>.from(usageRes as List),
    );

    final summaries =
        usageByUser.entries
            .where((e) => _hasUsageInPeriod(e.value))
            .map(
              (e) => _summaryForUser(
                e.key,
                e.value.name.isNotEmpty ? e.value.name : e.key,
                e.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byOpens = b.weekOpens.compareTo(a.weekOpens);
            if (byOpens != 0) return byOpens;
            final byDays = b.activeDays.compareTo(a.activeDays);
            if (byDays != 0) return byDays;
            return a.userName.compareTo(b.userName);
          });

    return summaries;
  }

  bool _hasUsageInPeriod(_Agg agg) =>
      agg.weekOpens > 0 ||
      agg.activeDays.isNotEmpty ||
      agg.tabCounts.isNotEmpty;

  Map<String, _Agg> _aggregateUsage(List<Map<String, dynamic>> rows) {
    final byUser = <String, _Agg>{};

    for (final row in rows) {
      final userId = (row['user_id'] ?? '').toString();
      if (userId.isEmpty) continue;

      final agg = byUser.putIfAbsent(
        userId,
        () => _Agg(name: (row['user_name'] ?? '').toString()),
      );
      if (agg.name.isEmpty) {
        agg.name = (row['user_name'] ?? '').toString();
      }

      final opens = row['app_opens'];
      if (opens is num) {
        agg.weekOpens += opens.toInt();
      }

      final usageDate = row['usage_date']?.toString();
      if (usageDate != null && usageDate.isNotEmpty) {
        agg.activeDays.add(usageDate);
      }

      final tabCounts = row['tab_counts'];
      if (tabCounts is Map) {
        for (final entry in tabCounts.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is num) {
            agg.tabCounts[key] = (agg.tabCounts[key] ?? 0) + value.toInt();
          }
        }
      }

      final updatedRaw = row['updated_at']?.toString();
      if (updatedRaw != null && updatedRaw.isNotEmpty) {
        try {
          final updated = parseSupabaseTimestampAsSeoul(updatedRaw);
          if (agg.lastUsed == null || updated.isAfter(agg.lastUsed!)) {
            agg.lastUsed = updated;
          }
        } catch (_) {}
      }
    }

    return byUser;
  }

  AppUsageSummary _summaryForUser(String userId, String userName, _Agg? agg) {
    return AppUsageSummary(
      userId: userId,
      userName: userName.isNotEmpty ? userName : userId,
      weekOpens: agg?.weekOpens ?? 0,
      activeDays: agg?.activeDays.length ?? 0,
      topTabKey: topTabKeyFromCounts(agg?.tabCounts ?? const {}),
      lastUsed: agg?.lastUsed,
    );
  }
}

class _Agg {
  _Agg({required this.name});

  String name;
  int weekOpens = 0;
  final Set<String> activeDays = {};
  final Map<String, int> tabCounts = {};
  DateTime? lastUsed;
}
