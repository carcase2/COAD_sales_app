class EstimateDocument {
  EstimateDocument({
    required this.id,
    required this.category,
    required this.modelName,
    required this.customerName,
    required this.siteName,
    required this.widthMm,
    required this.heightMm,
    required this.quantity,
    required this.baseAmount,
    required this.extraItems,
    required this.customFields,
    required this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String category;
  final String modelName;
  final String customerName;
  final String siteName;
  final int widthMm;
  final int heightMm;
  final int quantity;
  final int baseAmount;
  final List<EstimateExtraItem> extraItems;
  final Map<String, String> customFields;
  final String memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalAmount =>
      baseAmount +
      extraItems.fold<int>(
        0,
        (sum, item) => sum + (item.amount * item.quantity),
      );

  EstimateDocument copyWith({
    String? id,
    String? category,
    String? modelName,
    String? customerName,
    String? siteName,
    int? widthMm,
    int? heightMm,
    int? quantity,
    int? baseAmount,
    List<EstimateExtraItem>? extraItems,
    Map<String, String>? customFields,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EstimateDocument(
      id: id ?? this.id,
      category: category ?? this.category,
      modelName: modelName ?? this.modelName,
      customerName: customerName ?? this.customerName,
      siteName: siteName ?? this.siteName,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      quantity: quantity ?? this.quantity,
      baseAmount: baseAmount ?? this.baseAmount,
      extraItems: extraItems ?? this.extraItems,
      customFields: customFields ?? this.customFields,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'modelName': modelName,
      'customerName': customerName,
      'siteName': siteName,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'quantity': quantity,
      'baseAmount': baseAmount,
      'extraItems': extraItems.map((e) => e.toJson()).toList(),
      'customFields': customFields,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EstimateDocument.fromJson(Map<String, dynamic> json) {
    return EstimateDocument(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      modelName: (json['modelName'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      siteName: (json['siteName'] ?? '').toString(),
      widthMm: (json['widthMm'] as num?)?.toInt() ?? 0,
      heightMm: (json['heightMm'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      baseAmount: (json['baseAmount'] as num?)?.toInt() ?? 0,
      extraItems: ((json['extraItems'] as List?) ?? const [])
          .map(
            (e) =>
                EstimateExtraItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      customFields: Map<String, String>.from(
        json['customFields'] as Map? ?? const {},
      ),
      memo: (json['memo'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class EstimateExtraItem {
  EstimateExtraItem({
    required this.name,
    required this.amount,
    required this.quantity,
  });

  final String name;
  final int amount;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'quantity': quantity};
  }

  factory EstimateExtraItem.fromJson(Map<String, dynamic> json) {
    return EstimateExtraItem(
      name: (json['name'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}
