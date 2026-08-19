import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:flutter/material.dart';

Color hexToColor(String hex) {
  final normalized = normalizeHexColor(hex).replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

class StandardUnitPriceCategory {
  const StandardUnitPriceCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.color = '#334155',
  });

  final String id;
  final String name;
  final int sortOrder;
  final String color;

  factory StandardUnitPriceCategory.fromJson(Map<String, dynamic> json) {
    return StandardUnitPriceCategory(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      color: normalizeHexColor(json['color']?.toString()),
    );
  }
}

class StandardUnitPriceModel {
  const StandardUnitPriceModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
    this.color = '#334155',
  });

  final String id;
  final String categoryId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final String color;

  factory StandardUnitPriceModel.fromJson(Map<String, dynamic> json) {
    return StandardUnitPriceModel(
      id: '${json['id'] ?? ''}',
      categoryId: '${json['category_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      color: normalizeHexColor(json['color']?.toString()),
    );
  }
}

class StandardUnitPriceRow {
  const StandardUnitPriceRow({
    required this.id,
    required this.modelId,
    required this.widthMm,
    required this.heightMm,
    required this.price,
    this.available = true,
  });

  final String id;
  final String modelId;
  final int widthMm;
  final int heightMm;
  final int price;
  final bool available;

  StandardPriceCell get asCell => StandardPriceCell(
        id: id,
        widthMm: widthMm,
        heightMm: heightMm,
        price: price,
        available: available,
      );

  factory StandardUnitPriceRow.fromJson(Map<String, dynamic> json) {
    return StandardUnitPriceRow(
      id: '${json['id'] ?? ''}',
      modelId: '${json['model_id'] ?? ''}',
      widthMm: (json['width_mm'] as num?)?.toInt() ?? 0,
      heightMm: (json['height_mm'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.round() ?? 0,
      available: json['available'] != false,
    );
  }
}

class StandardUnitPriceCatalog {
  const StandardUnitPriceCatalog({
    required this.categories,
    required this.models,
  });

  final List<StandardUnitPriceCategory> categories;
  final List<StandardUnitPriceModel> models;

  List<StandardUnitPriceModel> modelsFor(String categoryId) => models
      .where((m) => m.categoryId == categoryId)
      .toList(growable: false);

  List<StandardUnitPriceCategory> get orderedCategories {
    final speed = <StandardUnitPriceCategory>[];
    final rest = <StandardUnitPriceCategory>[];
    for (final cat in categories) {
      if (cat.name.contains('스피드')) {
        speed.add(cat);
      } else {
        rest.add(cat);
      }
    }
    return [...speed, ...rest];
  }
}

class StandardUnitPriceAdjustment {
  const StandardUnitPriceAdjustment({
    required this.id,
    required this.modelId,
    required this.categoryId,
    required this.adjustmentType,
    required this.adjustmentValue,
    required this.reason,
    required this.cellsAffected,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.modelName,
    this.categoryName,
  });

  final String id;
  final String? modelId;
  final String? categoryId;
  final String adjustmentType;
  final num adjustmentValue;
  final String reason;
  final int cellsAffected;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final String? modelName;
  final String? categoryName;

  factory StandardUnitPriceAdjustment.fromJson(Map<String, dynamic> json) {
    final model = json['standard_unit_price_models'];
    String? modelName;
    String? categoryName;
    if (model is Map) {
      modelName = '${model['name'] ?? ''}';
      final cat = model['standard_unit_price_categories'];
      if (cat is Map) categoryName = '${cat['name'] ?? ''}';
    }
    return StandardUnitPriceAdjustment(
      id: '${json['id'] ?? ''}',
      modelId: json['model_id']?.toString(),
      categoryId: json['category_id']?.toString(),
      adjustmentType: '${json['adjustment_type'] ?? ''}',
      adjustmentValue: (json['adjustment_value'] as num?) ?? 0,
      reason: '${json['reason'] ?? ''}',
      cellsAffected: (json['cells_affected'] as num?)?.toInt() ?? 0,
      userId: '${json['user_id'] ?? ''}',
      userName: '${json['user_name'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      modelName: modelName,
      categoryName: categoryName,
    );
  }
}

class StandardUnitPriceChangeLog {
  const StandardUnitPriceChangeLog({
    required this.id,
    required this.adjustmentId,
    required this.modelId,
    required this.widthMm,
    required this.heightMm,
    required this.oldPrice,
    required this.newPrice,
    required this.changeType,
    required this.reason,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.modelName,
    this.categoryName,
  });

  final String id;
  final String? adjustmentId;
  final String? modelId;
  final int? widthMm;
  final int? heightMm;
  final int oldPrice;
  final int newPrice;
  final String changeType;
  final String reason;
  final String userId;
  final String userName;
  final DateTime createdAt;
  final String? modelName;
  final String? categoryName;

  factory StandardUnitPriceChangeLog.fromJson(Map<String, dynamic> json) {
    final model = json['standard_unit_price_models'];
    return StandardUnitPriceChangeLog(
      id: '${json['id'] ?? ''}',
      adjustmentId: json['adjustment_id']?.toString(),
      modelId: json['model_id']?.toString(),
      widthMm: (json['width_mm'] as num?)?.toInt(),
      heightMm: (json['height_mm'] as num?)?.toInt(),
      oldPrice: (json['old_price'] as num?)?.round() ?? 0,
      newPrice: (json['new_price'] as num?)?.round() ?? 0,
      changeType: '${json['change_type'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      userName: '${json['user_name'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      modelName: model is Map ? '${model['name'] ?? ''}' : null,
      categoryName: model is Map && model['standard_unit_price_categories'] is Map
          ? '${(model['standard_unit_price_categories'] as Map)['name'] ?? ''}'
          : null,
    );
  }
}
