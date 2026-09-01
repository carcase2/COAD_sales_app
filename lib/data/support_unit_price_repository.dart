import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportUnitPriceRepository {
  SupportUnitPriceRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SupportUnitPriceItem>> list() async {
    try {
      final res = await _client
          .from('support_as_unit_prices')
          .select()
          .isFilter('deleted_at', null)
          .order('sort_order')
          .order('product_line')
          .order('name');
      final items = List<Map<String, dynamic>>.from(res)
          .map(SupportUnitPriceItem.fromJson)
          .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
          .toList();
      items.sort(compareSupportUnitPriceItems);
      return items;
    } catch (e) {
      throw ApiException('A/S 단가표를 불러오지 못했습니다. $e');
    }
  }

  Future<List<SupportUnitPriceChangeLog>> listChangeLogs({
    String? itemId,
    int limit = 200,
  }) async {
    try {
      var query = _client.from('support_as_unit_price_change_logs').select();
      if (itemId != null && itemId.trim().isNotEmpty) {
        query = query.eq('item_id', itemId);
      }
      final res = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(
        res,
      ).map(SupportUnitPriceChangeLog.fromJson).toList();
    } catch (e) {
      throw ApiException('A/S 단가 이력을 불러오지 못했습니다. $e');
    }
  }

  Future<SupportUnitPriceItem> create({
    required String name,
    String spec = '',
    int? price,
    int? competitorPrice,
    String note = '',
    String productLine = '',
    String category = '',
    String nameEn = '',
    String unit = '',
    String kind = kSupportUnitPriceKindPart,
    String imageUrl = '',
    String diagramUrl = '',
    required String userId,
    required String userName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ApiException('품명을 입력해 주세요.');
    }
    try {
      await ensureSection(
        productLine: productLine,
        category: category,
      );
      final inserted = await _client
          .from('support_as_unit_prices')
          .insert({
            'name': trimmedName,
            'spec': spec.trim(),
            'price': price,
            'competitor_price': competitorPrice,
            'note': note.trim(),
            'product_line': productLine.trim(),
            'category': category.trim(),
            'name_en': nameEn.trim(),
            'unit': unit.trim(),
            'kind': kind == kSupportUnitPriceKindLabor
                ? kSupportUnitPriceKindLabor
                : kSupportUnitPriceKindPart,
            'image_url': imageUrl.trim(),
            'diagram_url': diagramUrl.trim(),
            'created_by': userId,
            'created_by_name': userName,
            'updated_by': userId,
            'updated_by_name': userName,
          })
          .select()
          .single();
      final item = SupportUnitPriceItem.fromJson(inserted);
      await _insertLog(
        action: 'create',
        item: item,
        oldItem: null,
        userId: userId,
        userName: userName,
      );
      return item;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 단가 추가에 실패했습니다. $e');
    }
  }

  Future<SupportUnitPriceItem> update({
    required SupportUnitPriceItem existing,
    required String name,
    String spec = '',
    int? price,
    int? competitorPrice,
    String note = '',
    String productLine = '',
    String category = '',
    String nameEn = '',
    String unit = '',
    String kind = kSupportUnitPriceKindPart,
    String imageUrl = '',
    String diagramUrl = '',
    required String userId,
    required String userName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ApiException('품명을 입력해 주세요.');
    }
    try {
      await ensureSection(
        productLine: productLine,
        category: category,
      );
      final updated = await _client
          .from('support_as_unit_prices')
          .update({
            'name': trimmedName,
            'spec': spec.trim(),
            'price': price,
            'competitor_price': competitorPrice,
            'note': note.trim(),
            'product_line': productLine.trim(),
            'category': category.trim(),
            'name_en': nameEn.trim(),
            'unit': unit.trim(),
            'kind': kind == kSupportUnitPriceKindLabor
                ? kSupportUnitPriceKindLabor
                : kSupportUnitPriceKindPart,
            'image_url': imageUrl.trim(),
            'diagram_url': diagramUrl.trim(),
            'updated_by': userId,
            'updated_by_name': userName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing.id)
          .select()
          .single();
      final item = SupportUnitPriceItem.fromJson(updated);
      await _insertLog(
        action: 'update',
        item: item,
        oldItem: existing,
        userId: userId,
        userName: userName,
      );
      return item;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 단가 수정에 실패했습니다. $e');
    }
  }

  Future<void> delete({
    required SupportUnitPriceItem item,
    required String userId,
    required String userName,
  }) async {
    try {
      await _client
          .from('support_as_unit_prices')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'deleted_by': userId,
            'deleted_by_name': userName,
            'updated_by': userId,
            'updated_by_name': userName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', item.id);
      await _insertLog(
        action: 'delete',
        item: item,
        oldItem: item,
        userId: userId,
        userName: userName,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 단가 삭제에 실패했습니다. $e');
    }
  }

  Future<void> migrateLocalIfNeeded(
    SharedPreferences prefs, {
    required String userId,
    required String userName,
  }) async {
    if (prefs.getBool(kSupportUnitPriceMigratedPrefKey) == true) return;
    final remote = await list();
    if (remote.isNotEmpty) {
      await prefs.setBool(kSupportUnitPriceMigratedPrefKey, true);
      return;
    }
    final local = SupportUnitPriceStore(prefs).load();
    for (final item in local.reversed) {
      await create(
        name: item.name,
        spec: item.spec,
        price: item.price,
        note: item.note,
        productLine: item.productLine,
        category: item.category,
        nameEn: item.nameEn,
        unit: item.unit,
        kind: item.kind,
        competitorPrice: item.competitorPrice,
        userId: userId,
        userName: userName,
      );
    }
    await prefs.setBool(kSupportUnitPriceMigratedPrefKey, true);
  }

  Future<void> _insertLog({
    required String action,
    required SupportUnitPriceItem item,
    required SupportUnitPriceItem? oldItem,
    required String userId,
    required String userName,
  }) async {
    final summary = describeSupportUnitPriceChange(
      action: action,
      oldName: oldItem?.name,
      oldSpec: oldItem?.spec,
      oldPrice: oldItem?.price,
      oldNote: oldItem?.note,
      newName: action == 'delete' ? oldItem?.name : item.name,
      newSpec: action == 'delete' ? oldItem?.spec : item.spec,
      newPrice: action == 'delete' ? oldItem?.price : item.price,
      newNote: action == 'delete' ? oldItem?.note : item.note,
      oldUnit: oldItem?.unit,
      newUnit: action == 'delete' ? oldItem?.unit : item.unit,
      oldCompetitorPrice: oldItem?.competitorPrice,
      newCompetitorPrice: action == 'delete'
          ? oldItem?.competitorPrice
          : item.competitorPrice,
      oldProductLine: oldItem?.productLine,
      newProductLine: action == 'delete'
          ? oldItem?.productLine
          : item.productLine,
      oldCategory: oldItem?.category,
      newCategory: action == 'delete' ? oldItem?.category : item.category,
    );
    await _client.from('support_as_unit_price_change_logs').insert({
      'item_id': item.id,
      'action': action,
      'item_name': (action == 'delete' ? oldItem?.name : item.name) ?? '',
      'old_name': oldItem?.name,
      'old_spec': oldItem?.spec,
      'old_price': oldItem?.price,
      'old_note': oldItem?.note,
      'new_name': action == 'delete' ? null : item.name,
      'new_spec': action == 'delete' ? null : item.spec,
      'new_price': action == 'delete' ? null : item.price,
      'new_note': action == 'delete' ? null : item.note,
      'summary': summary,
      'user_id': userId,
      'user_name': userName,
    });
  }

  Future<List<SupportUnitPriceSection>> listSections() async {
    try {
      final res = await _client
          .from('support_as_unit_price_sections')
          .select()
          .order('product_line')
          .order('sort_order')
          .order('category');
      return List<Map<String, dynamic>>.from(
        res,
      ).map(SupportUnitPriceSection.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> ensureSection({
    required String productLine,
    required String category,
  }) async {
    final line = productLine.trim();
    if (line.isEmpty) return;
    try {
      await _client.from('support_as_unit_price_sections').upsert({
        'product_line': line,
        'category': category.trim(),
      }, onConflict: 'product_line,category');
    } catch (_) {}
  }

  Future<void> addSection({
    required String productLine,
    required String category,
  }) async {
    final line = productLine.trim();
    if (line.isEmpty) {
      throw ApiException('큰분류를 입력해 주세요.');
    }
    try {
      await _client.from('support_as_unit_price_sections').upsert({
        'product_line': line,
        'category': category.trim(),
      }, onConflict: 'product_line,category');
    } catch (e) {
      throw ApiException('분류를 추가하지 못했습니다. $e');
    }
  }

  Future<void> renameProductLine({
    required String from,
    required String to,
  }) async {
    final oldLine = from.trim();
    final newLine = to.trim();
    if (oldLine.isEmpty || newLine.isEmpty) {
      throw ApiException('큰분류 이름을 입력해 주세요.');
    }
    if (oldLine == newLine) return;
    try {
      await _client
          .from('support_as_unit_prices')
          .update({'product_line': newLine})
          .eq('product_line', oldLine)
          .isFilter('deleted_at', null);
      await _client
          .from('support_as_unit_price_sections')
          .update({'product_line': newLine})
          .eq('product_line', oldLine);
    } catch (e) {
      throw ApiException('큰분류 이름을 바꾸지 못했습니다. $e');
    }
  }

  Future<void> renameCategory({
    required String productLine,
    required String from,
    required String to,
  }) async {
    final line = productLine.trim();
    final oldCat = from.trim();
    final newCat = to.trim();
    if (line.isEmpty || newCat.isEmpty) {
      throw ApiException('작은분류 이름을 입력해 주세요.');
    }
    if (oldCat == newCat) return;
    try {
      await _client
          .from('support_as_unit_prices')
          .update({'category': newCat})
          .eq('product_line', line)
          .eq('category', oldCat)
          .isFilter('deleted_at', null);
      await _client
          .from('support_as_unit_price_sections')
          .update({'category': newCat})
          .eq('product_line', line)
          .eq('category', oldCat);
    } catch (e) {
      throw ApiException('작은분류 이름을 바꾸지 못했습니다. $e');
    }
  }

  Future<int> countItems({
    required String productLine,
    String? category,
  }) async {
    final line = productLine.trim();
    var query = _client
        .from('support_as_unit_prices')
        .select('id')
        .eq('product_line', line)
        .isFilter('deleted_at', null);
    if (category != null) {
      query = query.eq('category', category);
    }
    final res = await query;
    return List<dynamic>.from(res).length;
  }

  Future<void> deleteProductLine({
    required String productLine,
    required String userId,
    required String userName,
  }) async {
    final line = productLine.trim();
    if (line.isEmpty) return;
    try {
      final items = (await list()).where((e) => e.productLine.trim() == line);
      for (final item in items) {
        await delete(item: item, userId: userId, userName: userName);
      }
      await _client
          .from('support_as_unit_price_sections')
          .delete()
          .eq('product_line', line);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('큰분류를 삭제하지 못했습니다. $e');
    }
  }

  Future<void> deleteCategory({
    required String productLine,
    required String category,
    required String userId,
    required String userName,
  }) async {
    final line = productLine.trim();
    final cat = category.trim();
    try {
      final items = (await list()).where(
        (e) => e.productLine.trim() == line && e.category.trim() == cat,
      );
      for (final item in items) {
        await delete(item: item, userId: userId, userName: userName);
      }
      await _client
          .from('support_as_unit_price_sections')
          .delete()
          .eq('product_line', line)
          .eq('category', cat);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('작은분류를 삭제하지 못했습니다. $e');
    }
  }
}
