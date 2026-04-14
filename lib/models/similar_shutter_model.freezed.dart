// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'similar_shutter_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SimilarShutterEstimate _$SimilarShutterEstimateFromJson(
  Map<String, dynamic> json,
) {
  return _SimilarShutterEstimate.fromJson(json);
}

/// @nodoc
mixin _$SimilarShutterEstimate {
  String get id => throw _privateConstructorUsedError;
  double get width => throw _privateConstructorUsedError;
  double get height => throw _privateConstructorUsedError;
  @JsonKey(name: 'model_id')
  String get modelId => throw _privateConstructorUsedError;
  @JsonKey(name: 'model_name')
  String? get modelName => throw _privateConstructorUsedError; // 조인으로 가져올 모델명
  double get amount => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_motor')
  bool get hasMotor => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this SimilarShutterEstimate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SimilarShutterEstimate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SimilarShutterEstimateCopyWith<SimilarShutterEstimate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SimilarShutterEstimateCopyWith<$Res> {
  factory $SimilarShutterEstimateCopyWith(
    SimilarShutterEstimate value,
    $Res Function(SimilarShutterEstimate) then,
  ) = _$SimilarShutterEstimateCopyWithImpl<$Res, SimilarShutterEstimate>;
  @useResult
  $Res call({
    String id,
    double width,
    double height,
    @JsonKey(name: 'model_id') String modelId,
    @JsonKey(name: 'model_name') String? modelName,
    double amount,
    @JsonKey(name: 'has_motor') bool hasMotor,
    String? description,
  });
}

/// @nodoc
class _$SimilarShutterEstimateCopyWithImpl<
  $Res,
  $Val extends SimilarShutterEstimate
>
    implements $SimilarShutterEstimateCopyWith<$Res> {
  _$SimilarShutterEstimateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SimilarShutterEstimate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? width = null,
    Object? height = null,
    Object? modelId = null,
    Object? modelName = freezed,
    Object? amount = null,
    Object? hasMotor = null,
    Object? description = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            width: null == width
                ? _value.width
                : width // ignore: cast_nullable_to_non_nullable
                      as double,
            height: null == height
                ? _value.height
                : height // ignore: cast_nullable_to_non_nullable
                      as double,
            modelId: null == modelId
                ? _value.modelId
                : modelId // ignore: cast_nullable_to_non_nullable
                      as String,
            modelName: freezed == modelName
                ? _value.modelName
                : modelName // ignore: cast_nullable_to_non_nullable
                      as String?,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as double,
            hasMotor: null == hasMotor
                ? _value.hasMotor
                : hasMotor // ignore: cast_nullable_to_non_nullable
                      as bool,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SimilarShutterEstimateImplCopyWith<$Res>
    implements $SimilarShutterEstimateCopyWith<$Res> {
  factory _$$SimilarShutterEstimateImplCopyWith(
    _$SimilarShutterEstimateImpl value,
    $Res Function(_$SimilarShutterEstimateImpl) then,
  ) = __$$SimilarShutterEstimateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    double width,
    double height,
    @JsonKey(name: 'model_id') String modelId,
    @JsonKey(name: 'model_name') String? modelName,
    double amount,
    @JsonKey(name: 'has_motor') bool hasMotor,
    String? description,
  });
}

/// @nodoc
class __$$SimilarShutterEstimateImplCopyWithImpl<$Res>
    extends
        _$SimilarShutterEstimateCopyWithImpl<$Res, _$SimilarShutterEstimateImpl>
    implements _$$SimilarShutterEstimateImplCopyWith<$Res> {
  __$$SimilarShutterEstimateImplCopyWithImpl(
    _$SimilarShutterEstimateImpl _value,
    $Res Function(_$SimilarShutterEstimateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SimilarShutterEstimate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? width = null,
    Object? height = null,
    Object? modelId = null,
    Object? modelName = freezed,
    Object? amount = null,
    Object? hasMotor = null,
    Object? description = freezed,
  }) {
    return _then(
      _$SimilarShutterEstimateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        width: null == width
            ? _value.width
            : width // ignore: cast_nullable_to_non_nullable
                  as double,
        height: null == height
            ? _value.height
            : height // ignore: cast_nullable_to_non_nullable
                  as double,
        modelId: null == modelId
            ? _value.modelId
            : modelId // ignore: cast_nullable_to_non_nullable
                  as String,
        modelName: freezed == modelName
            ? _value.modelName
            : modelName // ignore: cast_nullable_to_non_nullable
                  as String?,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as double,
        hasMotor: null == hasMotor
            ? _value.hasMotor
            : hasMotor // ignore: cast_nullable_to_non_nullable
                  as bool,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SimilarShutterEstimateImpl implements _SimilarShutterEstimate {
  const _$SimilarShutterEstimateImpl({
    required this.id,
    required this.width,
    required this.height,
    @JsonKey(name: 'model_id') required this.modelId,
    @JsonKey(name: 'model_name') this.modelName,
    required this.amount,
    @JsonKey(name: 'has_motor') required this.hasMotor,
    this.description,
  });

  factory _$SimilarShutterEstimateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SimilarShutterEstimateImplFromJson(json);

  @override
  final String id;
  @override
  final double width;
  @override
  final double height;
  @override
  @JsonKey(name: 'model_id')
  final String modelId;
  @override
  @JsonKey(name: 'model_name')
  final String? modelName;
  // 조인으로 가져올 모델명
  @override
  final double amount;
  @override
  @JsonKey(name: 'has_motor')
  final bool hasMotor;
  @override
  final String? description;

  @override
  String toString() {
    return 'SimilarShutterEstimate(id: $id, width: $width, height: $height, modelId: $modelId, modelName: $modelName, amount: $amount, hasMotor: $hasMotor, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SimilarShutterEstimateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height) &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.modelName, modelName) ||
                other.modelName == modelName) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.hasMotor, hasMotor) ||
                other.hasMotor == hasMotor) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    width,
    height,
    modelId,
    modelName,
    amount,
    hasMotor,
    description,
  );

  /// Create a copy of SimilarShutterEstimate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SimilarShutterEstimateImplCopyWith<_$SimilarShutterEstimateImpl>
  get copyWith =>
      __$$SimilarShutterEstimateImplCopyWithImpl<_$SimilarShutterEstimateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SimilarShutterEstimateImplToJson(this);
  }
}

abstract class _SimilarShutterEstimate implements SimilarShutterEstimate {
  const factory _SimilarShutterEstimate({
    required final String id,
    required final double width,
    required final double height,
    @JsonKey(name: 'model_id') required final String modelId,
    @JsonKey(name: 'model_name') final String? modelName,
    required final double amount,
    @JsonKey(name: 'has_motor') required final bool hasMotor,
    final String? description,
  }) = _$SimilarShutterEstimateImpl;

  factory _SimilarShutterEstimate.fromJson(Map<String, dynamic> json) =
      _$SimilarShutterEstimateImpl.fromJson;

  @override
  String get id;
  @override
  double get width;
  @override
  double get height;
  @override
  @JsonKey(name: 'model_id')
  String get modelId;
  @override
  @JsonKey(name: 'model_name')
  String? get modelName; // 조인으로 가져올 모델명
  @override
  double get amount;
  @override
  @JsonKey(name: 'has_motor')
  bool get hasMotor;
  @override
  String? get description;

  /// Create a copy of SimilarShutterEstimate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SimilarShutterEstimateImplCopyWith<_$SimilarShutterEstimateImpl>
  get copyWith => throw _privateConstructorUsedError;
}
