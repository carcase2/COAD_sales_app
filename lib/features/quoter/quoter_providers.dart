import 'dart:convert';

import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Duration shutterPriceCacheTtl = Duration(hours: 24);

typedef ShutterPriceListFetcher = Future<List<Map<String, dynamic>>> Function();

/// SharedPreferences에 저장된 단가 목록 JSON을 안전하게 파싱한다.
/// 손상·스키마 불일치 시 null.
List<Map<String, dynamic>>? parseCachedPriceList(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  } catch (_) {
    return null;
  }
}

bool isShutterPriceCacheFresh({
  required String? cachedAtRaw,
  required Duration ttl,
  DateTime? now,
}) {
  if (cachedAtRaw == null || cachedAtRaw.trim().isEmpty) return false;
  final cachedAt = DateTime.tryParse(cachedAtRaw);
  if (cachedAt == null) return false;
  return (now ?? DateTime.now()).difference(cachedAt) < ttl;
}

Future<void> clearShutterPriceCache(SharedPreferences prefs) async {
  await prefs.remove(StorageKeys.shutterPriceGridCache);
  await prefs.remove(StorageKeys.shutterPriceUnitCache);
  await prefs.remove(StorageKeys.shutterPriceCompanyCache);
  await prefs.remove(StorageKeys.shutterPriceCachedAt);
}

Future<void> writeShutterPriceCache(
  SharedPreferences prefs, {
  required List<Map<String, dynamic>> grid,
  required List<Map<String, dynamic>> unit,
  required List<Map<String, dynamic>> company,
  DateTime? now,
}) async {
  await prefs.setString(StorageKeys.shutterPriceGridCache, jsonEncode(grid));
  await prefs.setString(StorageKeys.shutterPriceUnitCache, jsonEncode(unit));
  await prefs.setString(
    StorageKeys.shutterPriceCompanyCache,
    jsonEncode(company),
  );
  await prefs.setString(
    StorageKeys.shutterPriceCachedAt,
    (now ?? DateTime.now()).toIso8601String(),
  );
}

/// 그리드/단가/회사 단가 로드. TTL 캐시 히트 시 디스크 사용.
/// [forceRefresh] true면 캐시를 무시하고 네트워크 후 덮어쓴다(1회성 — sticky 아님).
/// 회사 단가 fetch 실패 시 캐시 또는 빈 목록으로 폴백해 견적 전체가 실패하지 않게 한다.
Future<Map<String, List<Map<String, dynamic>>>> loadShutterPrices({
  required SharedPreferences prefs,
  required ShutterPriceListFetcher fetchGrid,
  required ShutterPriceListFetcher fetchUnit,
  required ShutterPriceListFetcher fetchCompany,
  bool forceRefresh = false,
  Duration ttl = shutterPriceCacheTtl,
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();

  Future<List<Map<String, dynamic>>> loadCompany({
    List<Map<String, dynamic>>? fallback,
  }) async {
    try {
      return await fetchCompany();
    } catch (_) {
      return fallback ??
          parseCachedPriceList(
            prefs.getString(StorageKeys.shutterPriceCompanyCache),
          ) ??
          const [];
    }
  }

  if (!forceRefresh) {
    final grid = parseCachedPriceList(
      prefs.getString(StorageKeys.shutterPriceGridCache),
    );
    final unit = parseCachedPriceList(
      prefs.getString(StorageKeys.shutterPriceUnitCache),
    );
    final companyCached = parseCachedPriceList(
      prefs.getString(StorageKeys.shutterPriceCompanyCache),
    );
    final fresh = isShutterPriceCacheFresh(
      cachedAtRaw: prefs.getString(StorageKeys.shutterPriceCachedAt),
      ttl: ttl,
      now: clock,
    );

    if (grid != null && unit != null && fresh) {
      // 회사 단가는 캐시가 있으면 그대로 사용(네트워크 불필요). 없으면 best-effort fetch.
      final company = companyCached ?? await loadCompany(fallback: const []);
      if (companyCached == null && company.isNotEmpty) {
        await prefs.setString(
          StorageKeys.shutterPriceCompanyCache,
          jsonEncode(company),
        );
      }
      return {'grid': grid, 'unit': unit, 'company': company};
    }
  }

  final grid = await fetchGrid();
  final unit = await fetchUnit();
  final company = await loadCompany();
  await writeShutterPriceCache(
    prefs,
    grid: grid,
    unit: unit,
    company: company,
    now: clock,
  );
  return {'grid': grid, 'unit': unit, 'company': company};
}

final shutterPricesFutureProvider = FutureProvider((ref) async {
  final repo = ref.read(shutterRepositoryProvider);
  final prefs = ref.read(appDependenciesProvider).prefs;
  return loadShutterPrices(
    prefs: prefs,
    fetchGrid: repo.fetchGridPrices,
    fetchUnit: repo.fetchUnitPrices,
    fetchCompany: repo.fetchCompanyPrices,
  );
});
