import 'package:freezed_annotation/freezed_annotation.dart';

part 'shutter_models.freezed.dart';
part 'shutter_models.g.dart';

enum ShutterType {
  @JsonValue('double_extrusion')
  doubleExtrusion, // 이중압출
  @JsonValue('double_extrusion_insulated')
  doubleExtrusionInsulated, // 이중압출단열
  @JsonValue('windproof')
  windproof, // 내풍압
  @JsonValue('windproof_insulated')
  windproofInsulated, // 내풍압단열
  @JsonValue('fire_steel')
  fireSteel, // 철제방화
  @JsonValue('fire_screen')
  fireScreen, // 스크린방화
}

@freezed
class ShutterEstimateInput with _$ShutterEstimateInput {
  const factory ShutterEstimateInput({
    required ShutterType type,
    required double widthMm,
    required double heightMm,
    @Default(1) int quantity,
    @Default(true) bool includeInstallation,
    @Default(true) bool includeEquipment,
    @Default(true) bool includeMotor,
    @Default(true) bool includeBending,
    @Default(true) bool includeProfit,
    
    // 비용 직접 수정 필드 추가
    int? overrideMotorCost,
    int? overrideInstallCost,
    int? overrideEquipCost,
    int? overrideBendingCost,
    int? overrideProfitCost,

    @Default([]) List<ShutterExtraItem> extraItems,
    String? memo,
  }) = _ShutterEstimateInput;

  factory ShutterEstimateInput.fromJson(Map<String, dynamic> json) =>
      _$ShutterEstimateInputFromJson(json);
}

@freezed
class ShutterExtraItem with _$ShutterExtraItem {
  const factory ShutterExtraItem({
    required String name,
    required int price,
    @Default(1) int quantity,
  }) = _ShutterExtraItem;

  factory ShutterExtraItem.fromJson(Map<String, dynamic> json) =>
      _$ShutterExtraItemFromJson(json);
}

@freezed
class ShutterEstimateResult with _$ShutterEstimateResult {
  const factory ShutterEstimateResult({
    required ShutterEstimateInput input,
    required int totalAmount,
    required List<ShutterBreakdownItem> breakdown,
    required double area,
    required double weightKg,
    required String motorModel,
    required String powerSpec,
    required String boxSize,
    required String bracketType,
    String? slatPriceNote, // 추가: 슬라트 계산 근거 (예: 10.5㎡ × 144,000원)
    required String calculatedAt,
  }) = _ShutterEstimateResult;

  factory ShutterEstimateResult.fromJson(Map<String, dynamic> json) =>
      _$ShutterEstimateResultFromJson(json);
}

@freezed
class ShutterBreakdownItem with _$ShutterBreakdownItem {
  const factory ShutterBreakdownItem({
    required String name,
    required int amount,
    String? note,
  }) = _ShutterBreakdownItem;

  factory ShutterBreakdownItem.fromJson(Map<String, dynamic> json) =>
      _$ShutterBreakdownItemFromJson(json);
}
