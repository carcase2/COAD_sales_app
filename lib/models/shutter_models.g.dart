// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shutter_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShutterEstimateInputImpl _$$ShutterEstimateInputImplFromJson(
  Map<String, dynamic> json,
) => _$ShutterEstimateInputImpl(
  type: $enumDecode(_$ShutterTypeEnumMap, json['type']),
  widthMm: (json['widthMm'] as num).toDouble(),
  heightMm: (json['heightMm'] as num).toDouble(),
  quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  includeInstallation: json['includeInstallation'] as bool? ?? true,
  includeEquipment: json['includeEquipment'] as bool? ?? true,
  includeMotor: json['includeMotor'] as bool? ?? true,
  includeBending: json['includeBending'] as bool? ?? true,
  includeProfit: json['includeProfit'] as bool? ?? true,
  overrideMotorCost: (json['overrideMotorCost'] as num?)?.toInt(),
  overrideInstallCost: (json['overrideInstallCost'] as num?)?.toInt(),
  overrideEquipCost: (json['overrideEquipCost'] as num?)?.toInt(),
  overrideBendingCost: (json['overrideBendingCost'] as num?)?.toInt(),
  overrideProfitCost: (json['overrideProfitCost'] as num?)?.toInt(),
  extraItems:
      (json['extraItems'] as List<dynamic>?)
          ?.map((e) => ShutterExtraItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  memo: json['memo'] as String?,
);

Map<String, dynamic> _$$ShutterEstimateInputImplToJson(
  _$ShutterEstimateInputImpl instance,
) => <String, dynamic>{
  'type': _$ShutterTypeEnumMap[instance.type]!,
  'widthMm': instance.widthMm,
  'heightMm': instance.heightMm,
  'quantity': instance.quantity,
  'includeInstallation': instance.includeInstallation,
  'includeEquipment': instance.includeEquipment,
  'includeMotor': instance.includeMotor,
  'includeBending': instance.includeBending,
  'includeProfit': instance.includeProfit,
  'overrideMotorCost': instance.overrideMotorCost,
  'overrideInstallCost': instance.overrideInstallCost,
  'overrideEquipCost': instance.overrideEquipCost,
  'overrideBendingCost': instance.overrideBendingCost,
  'overrideProfitCost': instance.overrideProfitCost,
  'extraItems': instance.extraItems,
  'memo': instance.memo,
};

const _$ShutterTypeEnumMap = {
  ShutterType.doubleExtrusion: 'double_extrusion',
  ShutterType.doubleExtrusionInsulated: 'double_extrusion_insulated',
  ShutterType.windproof: 'windproof',
  ShutterType.windproofInsulated: 'windproof_insulated',
  ShutterType.fireSteel: 'fire_steel',
  ShutterType.fireScreen: 'fire_screen',
};

_$ShutterExtraItemImpl _$$ShutterExtraItemImplFromJson(
  Map<String, dynamic> json,
) => _$ShutterExtraItemImpl(
  name: json['name'] as String,
  price: (json['price'] as num).toInt(),
  quantity: (json['quantity'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$$ShutterExtraItemImplToJson(
  _$ShutterExtraItemImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'price': instance.price,
  'quantity': instance.quantity,
};

_$ShutterEstimateResultImpl _$$ShutterEstimateResultImplFromJson(
  Map<String, dynamic> json,
) => _$ShutterEstimateResultImpl(
  input: ShutterEstimateInput.fromJson(json['input'] as Map<String, dynamic>),
  totalAmount: (json['totalAmount'] as num).toInt(),
  breakdown: (json['breakdown'] as List<dynamic>)
      .map((e) => ShutterBreakdownItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  area: (json['area'] as num).toDouble(),
  weightKg: (json['weightKg'] as num).toDouble(),
  motorModel: json['motorModel'] as String,
  powerSpec: json['powerSpec'] as String,
  boxSize: json['boxSize'] as String,
  bracketType: json['bracketType'] as String,
  slatPriceNote: json['slatPriceNote'] as String?,
  calculatedAt: json['calculatedAt'] as String,
);

Map<String, dynamic> _$$ShutterEstimateResultImplToJson(
  _$ShutterEstimateResultImpl instance,
) => <String, dynamic>{
  'input': instance.input,
  'totalAmount': instance.totalAmount,
  'breakdown': instance.breakdown,
  'area': instance.area,
  'weightKg': instance.weightKg,
  'motorModel': instance.motorModel,
  'powerSpec': instance.powerSpec,
  'boxSize': instance.boxSize,
  'bracketType': instance.bracketType,
  'slatPriceNote': instance.slatPriceNote,
  'calculatedAt': instance.calculatedAt,
};

_$ShutterBreakdownItemImpl _$$ShutterBreakdownItemImplFromJson(
  Map<String, dynamic> json,
) => _$ShutterBreakdownItemImpl(
  name: json['name'] as String,
  amount: (json['amount'] as num).toInt(),
  note: json['note'] as String?,
);

Map<String, dynamic> _$$ShutterBreakdownItemImplToJson(
  _$ShutterBreakdownItemImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount': instance.amount,
  'note': instance.note,
};
