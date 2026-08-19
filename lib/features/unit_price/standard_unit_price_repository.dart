import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StandardUnitPriceRepository {
  StandardUnitPriceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<StandardUnitPriceCatalog> fetchCatalog() async {
    final cats = await _client
        .from('standard_unit_price_categories')
        .select()
        .order('sort_order')
        .order('name');
    final models = await _client
        .from('standard_unit_price_models')
        .select()
        .order('sort_order')
        .order('name');
    return StandardUnitPriceCatalog(
      categories: List<Map<String, dynamic>>.from(cats)
          .map(StandardUnitPriceCategory.fromJson)
          .toList()
        ..sort((a, b) {
          if (a.name == '스피드도어' && b.name != '스피드도어') return -1;
          if (b.name == '스피드도어' && a.name != '스피드도어') return 1;
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          if (byOrder != 0) return byOrder;
          return a.name.compareTo(b.name);
        }),
      models: List<Map<String, dynamic>>.from(models)
          .map(StandardUnitPriceModel.fromJson)
          .toList(),
    );
  }

  Future<List<StandardUnitPriceRow>> fetchAllPrices() async {
    final res = await _client
        .from('standard_unit_prices')
        .select()
        .order('model_id')
        .order('height_mm')
        .order('width_mm');
    return List<Map<String, dynamic>>.from(res)
        .map(StandardUnitPriceRow.fromJson)
        .toList();
  }

  Future<List<StandardUnitPriceRow>> fetchPrices(String modelId) async {
    final res = await _client
        .from('standard_unit_prices')
        .select()
        .eq('model_id', modelId)
        .order('height_mm')
        .order('width_mm');
    return List<Map<String, dynamic>>.from(res)
        .map(StandardUnitPriceRow.fromJson)
        .toList();
  }

  Future<void> updateCell({
    required String id,
    required String modelId,
    required int widthMm,
    required int heightMm,
    required int oldPrice,
    required int newPrice,
    required bool available,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw StateError('수정 사유를 입력해 주세요.');
    }
    final patch = {
      'price': newPrice,
      'available': available,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id.isEmpty) {
      await _client.from('standard_unit_prices').upsert({
        'model_id': modelId,
        'width_mm': widthMm,
        'height_mm': heightMm,
        ...patch,
      }, onConflict: 'model_id,width_mm,height_mm');
    } else {
      await _client.from('standard_unit_prices').update(patch).eq('id', id);
    }

    final adj = await _client
        .from('standard_unit_price_adjustments')
        .insert({
          'model_id': modelId,
          'adjustment_type': 'manual',
          'adjustment_value': newPrice - oldPrice,
          'reason': trimmed,
          'cells_affected': 1,
          'user_id': userId,
          'user_name': userName,
        })
        .select('id')
        .single();

    await _client.from('standard_unit_price_change_logs').insert({
      'adjustment_id': adj['id'],
      'model_id': modelId,
      'width_mm': widthMm,
      'height_mm': heightMm,
      'old_price': oldPrice,
      'new_price': newPrice,
      'change_type': 'manual',
      'reason': trimmed,
      'user_id': userId,
      'user_name': userName,
    });
  }

  Future<String> applyAdjustment({
    required String modelId,
    required StandardAdjustType type,
    required num value,
    required String reason,
    required String userId,
    required String userName,
  }) async {
    final data = await _client.rpc(
      'apply_standard_unit_price_adjustment',
      params: {
        'p_model_id': modelId,
        'p_adjustment_type':
            type == StandardAdjustType.percent ? 'percent' : 'amount',
        'p_adjustment_value': value,
        'p_reason': reason.trim(),
        'p_user_id': userId,
        'p_user_name': userName,
      },
    );
    return '$data';
  }

  Future<List<StandardUnitPriceAdjustment>> fetchAdjustments({
    int limit = 40,
  }) async {
    final res = await _client
        .from('standard_unit_price_adjustments')
        .select(
          '*, standard_unit_price_models(name, standard_unit_price_categories(name))',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(res)
        .map(StandardUnitPriceAdjustment.fromJson)
        .toList();
  }

  Future<List<StandardUnitPriceChangeLog>> fetchChangeLogs({
    String? modelId,
    String? adjustmentId,
    int limit = 80,
  }) async {
    var query = _client
        .from('standard_unit_price_change_logs')
        .select(
          '*, standard_unit_price_models(name, standard_unit_price_categories(name))',
        );
    if (modelId != null) query = query.eq('model_id', modelId);
    if (adjustmentId != null) query = query.eq('adjustment_id', adjustmentId);
    final res = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res)
        .map(StandardUnitPriceChangeLog.fromJson)
        .toList();
  }

  Future<void> addCategory(String name, {String? color}) async {
    await _client.from('standard_unit_price_categories').insert({
      'name': name.trim(),
      'sort_order': 100,
      'color': normalizeHexColor(color),
    });
  }

  Future<void> updateCategory({required String id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('분류명을 입력해 주세요.');
    await _client.from('standard_unit_price_categories').update({
      'name': trimmed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('standard_unit_price_categories').delete().eq('id', id);
  }

  Future<void> addModel({
    required String categoryId,
    required String name,
    String? color,
  }) async {
    final row = await _client
        .from('standard_unit_price_models')
        .insert({
          'category_id': categoryId,
          'name': name.trim(),
          'sort_order': 100,
          'color': normalizeHexColor(color),
        })
        .select('id')
        .single();
    await _client.rpc(
      'ensure_standard_unit_price_grid',
      params: {'p_model_id': row['id']},
    );
  }

  Future<void> updateModel({
    required String id,
    required String name,
    String? categoryId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('모델명을 입력해 주세요.');
    final patch = <String, dynamic>{
      'name': trimmed,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (categoryId != null) patch['category_id'] = categoryId;
    await _client.from('standard_unit_price_models').update(patch).eq('id', id);
  }

  Future<void> deleteModel(String id) async {
    await _client.from('standard_unit_price_models').delete().eq('id', id);
  }
}

final standardUnitPriceRepositoryProvider = Provider(
  (ref) => StandardUnitPriceRepository(),
);
