import 'package:freezed_annotation/freezed_annotation.dart';

part 'similar_shutter_model.freezed.dart';
part 'similar_shutter_model.g.dart';

@freezed
class SimilarShutterEstimate with _$SimilarShutterEstimate {
  const factory SimilarShutterEstimate({
    required String id,
    required double width,
    required double height,
    @JsonKey(name: 'model_id') required String modelId,
    @JsonKey(name: 'model_name') String? modelName, // 조인으로 가져올 모델명
    required double amount,
    @JsonKey(name: 'has_motor') required bool hasMotor,
    String? description,
  }) = _SimilarShutterEstimate;

  factory SimilarShutterEstimate.fromJson(Map<String, dynamic> json) =>
      _$SimilarShutterEstimateFromJson(json);
}
