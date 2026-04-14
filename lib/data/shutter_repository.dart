import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
