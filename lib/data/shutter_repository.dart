import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 셔터 견적기 사용 이력 1건 (coad_home shutter_estimator_log).
class ShutterEstimatorLogEntry {
  const ShutterEstimatorLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.widthMm,
    required this.heightMm,
    required this.modelType,
    required this.totalPrice,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userName;
  final int widthMm;
  final int heightMm;
  final String modelType;
  final int totalPrice;
  final DateTime createdAt;

  factory ShutterEstimatorLogEntry.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    DateTime created;
    if (createdRaw is DateTime) {
      created = createdRaw;
    } else {
      created = DateTime.tryParse('$createdRaw') ?? DateTime.now();
    }
    return ShutterEstimatorLogEntry(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      userName: '${json['user_name'] ?? ''}',
      widthMm: (json['width_mm'] as num?)?.toInt() ?? 0,
      heightMm: (json['height_mm'] as num?)?.toInt() ?? 0,
      modelType: '${json['model_type'] ?? ''}',
      totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
      createdAt: created,
    );
  }
}

class ShutterEstimatorUserStat {
  const ShutterEstimatorUserStat({
    required this.userId,
    required this.userName,
    required this.count,
    required this.totalPriceSum,
  });

  final String userId;
  final String userName;
  final int count;
  final int totalPriceSum;
}

class ShutterEstimatorLogBundle {
  const ShutterEstimatorLogBundle({
    required this.history,
    required this.totalCount,
    required this.byUser,
  });

  final List<ShutterEstimatorLogEntry> history;
  final int totalCount;
  final List<ShutterEstimatorUserStat> byUser;

  int get totalPriceSum =>
      byUser.fold<int>(0, (s, u) => s + u.totalPriceSum);
}

class ShutterRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchGridPrices() async {
    final res = await _client.from('shutter_unit_price_grid').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchUnitPrices() async {
    final res = await _client.from('shutter_unit_prices').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCompanyPrices() async {
    final res = await _client.from('shutter_company_unit_prices').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> logEstimate(Map<String, dynamic> logData) async {
    // 제공된 스키마: user_id, user_name, width_mm, height_mm, model_type, total_price, created_at
    await _client.from('shutter_estimator_log').insert(logData);
  }

  /// 관리자용 견적기 사용 이력 + 사용자별 통계 (coad_home API GET 과 동일 데이터).
  Future<ShutterEstimatorLogBundle> fetchEstimatorLogs({
    required DateTime since,
    int limit = 200,
  }) async {
    final capped = limit.clamp(1, 500);
    final sinceIso = since.toUtc().toIso8601String();

    final historyRes = await _client
        .from('shutter_estimator_log')
        .select()
        .gte('created_at', sinceIso)
        .order('created_at', ascending: false)
        .limit(capped);

    final statsRes = await _client
        .from('shutter_estimator_log')
        .select('user_id, user_name, total_price')
        .gte('created_at', sinceIso);

    final history = List<Map<String, dynamic>>.from(historyRes)
        .map(ShutterEstimatorLogEntry.fromJson)
        .toList();

    final byUserMap = <String, ShutterEstimatorUserStat>{};
    for (final row in List<Map<String, dynamic>>.from(statsRes)) {
      final uid = '${row['user_id'] ?? ''}';
      if (uid.isEmpty) continue;
      final name = '${row['user_name'] ?? ''}';
      final price = (row['total_price'] as num?)?.toInt() ?? 0;
      final prev = byUserMap[uid];
      if (prev == null) {
        byUserMap[uid] = ShutterEstimatorUserStat(
          userId: uid,
          userName: name.isEmpty ? uid : name,
          count: 1,
          totalPriceSum: price,
        );
      } else {
        byUserMap[uid] = ShutterEstimatorUserStat(
          userId: uid,
          userName: prev.userName.isNotEmpty ? prev.userName : name,
          count: prev.count + 1,
          totalPriceSum: prev.totalPriceSum + price,
        );
      }
    }

    final byUser = byUserMap.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return ShutterEstimatorLogBundle(
      history: history,
      totalCount: List<Map<String, dynamic>>.from(statsRes).length,
      byUser: byUser,
    );
  }

  Future<String?> fetchShutterModelId(String category, String? modelType) async {
    // 모델 전체 로드 (스키마 확인 결과: name, description 컬럼 존재)
    final List<dynamic> res = await _client
        .from('shutter_models')
        .select();

    if (res.isEmpty) return null;

    // 1순위: 'name' 컬럼에서 카테고리(철제방화, 방화스크린 등) 단어가 포함된 행 찾기
    for (final row in res) {
      final map = row as Map<String, dynamic>;
      final name = (map['name'] ?? '').toString();
      
      // 방화스크린셔터 같이 순서가 다를 수 있으므로 포함 여부 확인
      bool categoryMatch = name.contains(category) || category.contains(name);
      bool typeMatch = modelType == null || name.contains(modelType);

      if (categoryMatch && typeMatch) {
        return map['id']?.toString();
      }
    }

    // 2순위: 더 느슨한 검색 (단어 분리 매칭)
    final terms = category.split(RegExp(r'방화|셔터| ')).where((t) => t.length >= 2).toList();
    for (final row in res) {
      final map = row as Map<String, dynamic>;
      final name = (map['name'] ?? '').toString();
      if (terms.any((t) => name.contains(t))) {
         // 카테고리(방합, 스크린 등) 키워드가 들어있으면 반환
         if (category.contains('스크린') && name.contains('스크린')) return map['id']?.toString();
         if (category.contains('철제') && name.contains('철제')) return map['id']?.toString();
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchSimpleEstimates(String modelId) async {
    final List<dynamic> res = await _client
        .from('simple_shutter_estimates')
        .select('*, shutter_models(name)')
        .eq('model_id', modelId);
    
    // 조인된 shutter_models(name)을 model_name으로, includes_motor를 has_motor로 평탄화
    return List<Map<String, dynamic>>.from(res.map((e) {
      final map = Map<String, dynamic>.from(e);
      // 모델명 추출
      final modelData = e['shutter_models'];
      if (modelData is Map) {
        map['model_name'] = modelData['name'];
      }
      // 컬럼명 매핑 (스키마: includes_motor -> 모델: has_motor)
      map['has_motor'] = e['includes_motor'] ?? false;
      return map;
    }));
  }
}

final shutterRepositoryProvider = Provider((ref) => ShutterRepository());
