import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/app_usage_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsageRepository {
  UsageRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 최근 [days]일 사용량을 사용자별로 합산한다.
  Future<List<AppUsageSummary>> fetchSummaries({int days = 7}) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    final startYmd = ymdSeoulFromDateTime(start);

    final res = await _client
        .from('app_usage_daily')
        .select('user_id, user_name, usage_date, app_opens, tab_counts, updated_at')
        .gte('usage_date', startYmd)
        .order('usage_date', ascending: false);

    final rows = List<Map<String, dynamic>>.from(res as List);
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

    final summaries = byUser.entries
        .map(
          (e) => AppUsageSummary(
            userId: e.key,
            userName: e.value.name.isNotEmpty ? e.value.name : e.key,
            weekOpens: e.value.weekOpens,
            activeDays: e.value.activeDays.length,
            topTabKey: topTabKeyFromCounts(e.value.tabCounts),
            lastUsed: e.value.lastUsed,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byOpens = b.weekOpens.compareTo(a.weekOpens);
        if (byOpens != 0) return byOpens;
        return b.activeDays.compareTo(a.activeDays);
      });

    return summaries;
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
