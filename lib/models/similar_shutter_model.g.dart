// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'similar_shutter_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SimilarShutterEstimateImpl _$$SimilarShutterEstimateImplFromJson(
  Map<String, dynamic> json,
) => _$SimilarShutterEstimateImpl(
  id: json['id'] as String,
  width: (json['width'] as num).toDouble(),
  height: (json['height'] as num).toDouble(),
  modelId: json['model_id'] as String,
  modelName: json['model_name'] as String?,
  amount: (json['amount'] as num).toDouble(),
  hasMotor: json['has_motor'] as bool,
  description: json['description'] as String?,
);

Map<String, dynamic> _$$SimilarShutterEstimateImplToJson(
  _$SimilarShutterEstimateImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'width': instance.width,
  'height': instance.height,
  'model_id': instance.modelId,
  'model_name': instance.modelName,
  'amount': instance.amount,
  'has_motor': instance.hasMotor,
  'description': instance.description,
};
