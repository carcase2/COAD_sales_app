// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shutter_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ShutterEstimateInput _$ShutterEstimateInputFromJson(Map<String, dynamic> json) {
  return _ShutterEstimateInput.fromJson(json);
}

/// @nodoc
mixin _$ShutterEstimateInput {
  ShutterType get type => throw _privateConstructorUsedError;
  double get widthMm => throw _privateConstructorUsedError;
  double get heightMm => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  bool get includeInstallation => throw _privateConstructorUsedError;
  bool get includeEquipment => throw _privateConstructorUsedError;
  bool get includeMotor => throw _privateConstructorUsedError;
  bool get includeBending => throw _privateConstructorUsedError;
  bool get includeProfit =>
      throw _privateConstructorUsedError; // 비용 직접 수정 필드 추가
  int? get overrideMotorCost => throw _privateConstructorUsedError;
  int? get overrideInstallCost => throw _privateConstructorUsedError;
  int? get overrideEquipCost => throw _privateConstructorUsedError;
  int? get overrideBendingCost => throw _privateConstructorUsedError;
  int? get overrideProfitCost => throw _privateConstructorUsedError;
  List<ShutterExtraItem> get extraItems => throw _privateConstructorUsedError;
  String? get memo => throw _privateConstructorUsedError;

  /// Serializes this ShutterEstimateInput to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShutterEstimateInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShutterEstimateInputCopyWith<ShutterEstimateInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShutterEstimateInputCopyWith<$Res> {
  factory $ShutterEstimateInputCopyWith(
    ShutterEstimateInput value,
    $Res Function(ShutterEstimateInput) then,
  ) = _$ShutterEstimateInputCopyWithImpl<$Res, ShutterEstimateInput>;
  @useResult
  $Res call({
    ShutterType type,
    double widthMm,
    double heightMm,
    int quantity,
    bool includeInstallation,
    bool includeEquipment,
    bool includeMotor,
    bool includeBending,
    bool includeProfit,
    int? overrideMotorCost,
    int? overrideInstallCost,
    int? overrideEquipCost,
    int? overrideBendingCost,
    int? overrideProfitCost,
    List<ShutterExtraItem> extraItems,
    String? memo,
  });
}

/// @nodoc
class _$ShutterEstimateInputCopyWithImpl<
  $Res,
  $Val extends ShutterEstimateInput
>
    implements $ShutterEstimateInputCopyWith<$Res> {
  _$ShutterEstimateInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShutterEstimateInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? widthMm = null,
    Object? heightMm = null,
    Object? quantity = null,
    Object? includeInstallation = null,
    Object? includeEquipment = null,
    Object? includeMotor = null,
    Object? includeBending = null,
    Object? includeProfit = null,
    Object? overrideMotorCost = freezed,
    Object? overrideInstallCost = freezed,
    Object? overrideEquipCost = freezed,
    Object? overrideBendingCost = freezed,
    Object? overrideProfitCost = freezed,
    Object? extraItems = null,
    Object? memo = freezed,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as ShutterType,
            widthMm: null == widthMm
                ? _value.widthMm
                : widthMm // ignore: cast_nullable_to_non_nullable
                      as double,
            heightMm: null == heightMm
                ? _value.heightMm
                : heightMm // ignore: cast_nullable_to_non_nullable
                      as double,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            includeInstallation: null == includeInstallation
                ? _value.includeInstallation
                : includeInstallation // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeEquipment: null == includeEquipment
                ? _value.includeEquipment
                : includeEquipment // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeMotor: null == includeMotor
                ? _value.includeMotor
                : includeMotor // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeBending: null == includeBending
                ? _value.includeBending
                : includeBending // ignore: cast_nullable_to_non_nullable
                      as bool,
            includeProfit: null == includeProfit
                ? _value.includeProfit
                : includeProfit // ignore: cast_nullable_to_non_nullable
                      as bool,
            overrideMotorCost: freezed == overrideMotorCost
                ? _value.overrideMotorCost
                : overrideMotorCost // ignore: cast_nullable_to_non_nullable
                      as int?,
            overrideInstallCost: freezed == overrideInstallCost
                ? _value.overrideInstallCost
                : overrideInstallCost // ignore: cast_nullable_to_non_nullable
                      as int?,
            overrideEquipCost: freezed == overrideEquipCost
                ? _value.overrideEquipCost
                : overrideEquipCost // ignore: cast_nullable_to_non_nullable
                      as int?,
            overrideBendingCost: freezed == overrideBendingCost
                ? _value.overrideBendingCost
                : overrideBendingCost // ignore: cast_nullable_to_non_nullable
                      as int?,
            overrideProfitCost: freezed == overrideProfitCost
                ? _value.overrideProfitCost
                : overrideProfitCost // ignore: cast_nullable_to_non_nullable
                      as int?,
            extraItems: null == extraItems
                ? _value.extraItems
                : extraItems // ignore: cast_nullable_to_non_nullable
                      as List<ShutterExtraItem>,
            memo: freezed == memo
                ? _value.memo
                : memo // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShutterEstimateInputImplCopyWith<$Res>
    implements $ShutterEstimateInputCopyWith<$Res> {
  factory _$$ShutterEstimateInputImplCopyWith(
    _$ShutterEstimateInputImpl value,
    $Res Function(_$ShutterEstimateInputImpl) then,
  ) = __$$ShutterEstimateInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ShutterType type,
    double widthMm,
    double heightMm,
    int quantity,
    bool includeInstallation,
    bool includeEquipment,
    bool includeMotor,
    bool includeBending,
    bool includeProfit,
    int? overrideMotorCost,
    int? overrideInstallCost,
    int? overrideEquipCost,
    int? overrideBendingCost,
    int? overrideProfitCost,
    List<ShutterExtraItem> extraItems,
    String? memo,
  });
}

/// @nodoc
class __$$ShutterEstimateInputImplCopyWithImpl<$Res>
    extends _$ShutterEstimateInputCopyWithImpl<$Res, _$ShutterEstimateInputImpl>
    implements _$$ShutterEstimateInputImplCopyWith<$Res> {
  __$$ShutterEstimateInputImplCopyWithImpl(
    _$ShutterEstimateInputImpl _value,
    $Res Function(_$ShutterEstimateInputImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShutterEstimateInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? widthMm = null,
    Object? heightMm = null,
    Object? quantity = null,
    Object? includeInstallation = null,
    Object? includeEquipment = null,
    Object? includeMotor = null,
    Object? includeBending = null,
    Object? includeProfit = null,
    Object? overrideMotorCost = freezed,
    Object? overrideInstallCost = freezed,
    Object? overrideEquipCost = freezed,
    Object? overrideBendingCost = freezed,
    Object? overrideProfitCost = freezed,
    Object? extraItems = null,
    Object? memo = freezed,
  }) {
    return _then(
      _$ShutterEstimateInputImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as ShutterType,
        widthMm: null == widthMm
            ? _value.widthMm
            : widthMm // ignore: cast_nullable_to_non_nullable
                  as double,
        heightMm: null == heightMm
            ? _value.heightMm
            : heightMm // ignore: cast_nullable_to_non_nullable
                  as double,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        includeInstallation: null == includeInstallation
            ? _value.includeInstallation
            : includeInstallation // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeEquipment: null == includeEquipment
            ? _value.includeEquipment
            : includeEquipment // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeMotor: null == includeMotor
            ? _value.includeMotor
            : includeMotor // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeBending: null == includeBending
            ? _value.includeBending
            : includeBending // ignore: cast_nullable_to_non_nullable
                  as bool,
        includeProfit: null == includeProfit
            ? _value.includeProfit
            : includeProfit // ignore: cast_nullable_to_non_nullable
                  as bool,
        overrideMotorCost: freezed == overrideMotorCost
            ? _value.overrideMotorCost
            : overrideMotorCost // ignore: cast_nullable_to_non_nullable
                  as int?,
        overrideInstallCost: freezed == overrideInstallCost
            ? _value.overrideInstallCost
            : overrideInstallCost // ignore: cast_nullable_to_non_nullable
                  as int?,
        overrideEquipCost: freezed == overrideEquipCost
            ? _value.overrideEquipCost
            : overrideEquipCost // ignore: cast_nullable_to_non_nullable
                  as int?,
        overrideBendingCost: freezed == overrideBendingCost
            ? _value.overrideBendingCost
            : overrideBendingCost // ignore: cast_nullable_to_non_nullable
                  as int?,
        overrideProfitCost: freezed == overrideProfitCost
            ? _value.overrideProfitCost
            : overrideProfitCost // ignore: cast_nullable_to_non_nullable
                  as int?,
        extraItems: null == extraItems
            ? _value._extraItems
            : extraItems // ignore: cast_nullable_to_non_nullable
                  as List<ShutterExtraItem>,
        memo: freezed == memo
            ? _value.memo
            : memo // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShutterEstimateInputImpl implements _ShutterEstimateInput {
  const _$ShutterEstimateInputImpl({
    required this.type,
    required this.widthMm,
    required this.heightMm,
    this.quantity = 1,
    this.includeInstallation = true,
    this.includeEquipment = true,
    this.includeMotor = true,
    this.includeBending = true,
    this.includeProfit = true,
    this.overrideMotorCost,
    this.overrideInstallCost,
    this.overrideEquipCost,
    this.overrideBendingCost,
    this.overrideProfitCost,
    final List<ShutterExtraItem> extraItems = const [],
    this.memo,
  }) : _extraItems = extraItems;

  factory _$ShutterEstimateInputImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShutterEstimateInputImplFromJson(json);

  @override
  final ShutterType type;
  @override
  final double widthMm;
  @override
  final double heightMm;
  @override
  @JsonKey()
  final int quantity;
  @override
  @JsonKey()
  final bool includeInstallation;
  @override
  @JsonKey()
  final bool includeEquipment;
  @override
  @JsonKey()
  final bool includeMotor;
  @override
  @JsonKey()
  final bool includeBending;
  @override
  @JsonKey()
  final bool includeProfit;
  // 비용 직접 수정 필드 추가
  @override
  final int? overrideMotorCost;
  @override
  final int? overrideInstallCost;
  @override
  final int? overrideEquipCost;
  @override
  final int? overrideBendingCost;
  @override
  final int? overrideProfitCost;
  final List<ShutterExtraItem> _extraItems;
  @override
  @JsonKey()
  List<ShutterExtraItem> get extraItems {
    if (_extraItems is EqualUnmodifiableListView) return _extraItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_extraItems);
  }

  @override
  final String? memo;

  @override
  String toString() {
    return 'ShutterEstimateInput(type: $type, widthMm: $widthMm, heightMm: $heightMm, quantity: $quantity, includeInstallation: $includeInstallation, includeEquipment: $includeEquipment, includeMotor: $includeMotor, includeBending: $includeBending, includeProfit: $includeProfit, overrideMotorCost: $overrideMotorCost, overrideInstallCost: $overrideInstallCost, overrideEquipCost: $overrideEquipCost, overrideBendingCost: $overrideBendingCost, overrideProfitCost: $overrideProfitCost, extraItems: $extraItems, memo: $memo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShutterEstimateInputImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.widthMm, widthMm) || other.widthMm == widthMm) &&
            (identical(other.heightMm, heightMm) ||
                other.heightMm == heightMm) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.includeInstallation, includeInstallation) ||
                other.includeInstallation == includeInstallation) &&
            (identical(other.includeEquipment, includeEquipment) ||
                other.includeEquipment == includeEquipment) &&
            (identical(other.includeMotor, includeMotor) ||
                other.includeMotor == includeMotor) &&
            (identical(other.includeBending, includeBending) ||
                other.includeBending == includeBending) &&
            (identical(other.includeProfit, includeProfit) ||
                other.includeProfit == includeProfit) &&
            (identical(other.overrideMotorCost, overrideMotorCost) ||
                other.overrideMotorCost == overrideMotorCost) &&
            (identical(other.overrideInstallCost, overrideInstallCost) ||
                other.overrideInstallCost == overrideInstallCost) &&
            (identical(other.overrideEquipCost, overrideEquipCost) ||
                other.overrideEquipCost == overrideEquipCost) &&
            (identical(other.overrideBendingCost, overrideBendingCost) ||
                other.overrideBendingCost == overrideBendingCost) &&
            (identical(other.overrideProfitCost, overrideProfitCost) ||
                other.overrideProfitCost == overrideProfitCost) &&
            const DeepCollectionEquality().equals(
              other._extraItems,
              _extraItems,
            ) &&
            (identical(other.memo, memo) || other.memo == memo));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    type,
    widthMm,
    heightMm,
    quantity,
    includeInstallation,
    includeEquipment,
    includeMotor,
    includeBending,
    includeProfit,
    overrideMotorCost,
    overrideInstallCost,
    overrideEquipCost,
    overrideBendingCost,
    overrideProfitCost,
    const DeepCollectionEquality().hash(_extraItems),
    memo,
  );

  /// Create a copy of ShutterEstimateInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShutterEstimateInputImplCopyWith<_$ShutterEstimateInputImpl>
  get copyWith =>
      __$$ShutterEstimateInputImplCopyWithImpl<_$ShutterEstimateInputImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShutterEstimateInputImplToJson(this);
  }
}

abstract class _ShutterEstimateInput implements ShutterEstimateInput {
  const factory _ShutterEstimateInput({
    required final ShutterType type,
    required final double widthMm,
    required final double heightMm,
    final int quantity,
    final bool includeInstallation,
    final bool includeEquipment,
    final bool includeMotor,
    final bool includeBending,
    final bool includeProfit,
    final int? overrideMotorCost,
    final int? overrideInstallCost,
    final int? overrideEquipCost,
    final int? overrideBendingCost,
    final int? overrideProfitCost,
    final List<ShutterExtraItem> extraItems,
    final String? memo,
  }) = _$ShutterEstimateInputImpl;

  factory _ShutterEstimateInput.fromJson(Map<String, dynamic> json) =
      _$ShutterEstimateInputImpl.fromJson;

  @override
  ShutterType get type;
  @override
  double get widthMm;
  @override
  double get heightMm;
  @override
  int get quantity;
  @override
  bool get includeInstallation;
  @override
  bool get includeEquipment;
  @override
  bool get includeMotor;
  @override
  bool get includeBending;
  @override
  bool get includeProfit; // 비용 직접 수정 필드 추가
  @override
  int? get overrideMotorCost;
  @override
  int? get overrideInstallCost;
  @override
  int? get overrideEquipCost;
  @override
  int? get overrideBendingCost;
  @override
  int? get overrideProfitCost;
  @override
  List<ShutterExtraItem> get extraItems;
  @override
  String? get memo;

  /// Create a copy of ShutterEstimateInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShutterEstimateInputImplCopyWith<_$ShutterEstimateInputImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ShutterExtraItem _$ShutterExtraItemFromJson(Map<String, dynamic> json) {
  return _ShutterExtraItem.fromJson(json);
}

/// @nodoc
mixin _$ShutterExtraItem {
  String get name => throw _privateConstructorUsedError;
  int get price => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;

  /// Serializes this ShutterExtraItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShutterExtraItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShutterExtraItemCopyWith<ShutterExtraItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShutterExtraItemCopyWith<$Res> {
  factory $ShutterExtraItemCopyWith(
    ShutterExtraItem value,
    $Res Function(ShutterExtraItem) then,
  ) = _$ShutterExtraItemCopyWithImpl<$Res, ShutterExtraItem>;
  @useResult
  $Res call({String name, int price, int quantity});
}

/// @nodoc
class _$ShutterExtraItemCopyWithImpl<$Res, $Val extends ShutterExtraItem>
    implements $ShutterExtraItemCopyWith<$Res> {
  _$ShutterExtraItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShutterExtraItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as int,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShutterExtraItemImplCopyWith<$Res>
    implements $ShutterExtraItemCopyWith<$Res> {
  factory _$$ShutterExtraItemImplCopyWith(
    _$ShutterExtraItemImpl value,
    $Res Function(_$ShutterExtraItemImpl) then,
  ) = __$$ShutterExtraItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, int price, int quantity});
}

/// @nodoc
class __$$ShutterExtraItemImplCopyWithImpl<$Res>
    extends _$ShutterExtraItemCopyWithImpl<$Res, _$ShutterExtraItemImpl>
    implements _$$ShutterExtraItemImplCopyWith<$Res> {
  __$$ShutterExtraItemImplCopyWithImpl(
    _$ShutterExtraItemImpl _value,
    $Res Function(_$ShutterExtraItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShutterExtraItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
  }) {
    return _then(
      _$ShutterExtraItemImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as int,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShutterExtraItemImpl implements _ShutterExtraItem {
  const _$ShutterExtraItemImpl({
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory _$ShutterExtraItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShutterExtraItemImplFromJson(json);

  @override
  final String name;
  @override
  final int price;
  @override
  @JsonKey()
  final int quantity;

  @override
  String toString() {
    return 'ShutterExtraItem(name: $name, price: $price, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShutterExtraItemImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, price, quantity);

  /// Create a copy of ShutterExtraItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShutterExtraItemImplCopyWith<_$ShutterExtraItemImpl> get copyWith =>
      __$$ShutterExtraItemImplCopyWithImpl<_$ShutterExtraItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShutterExtraItemImplToJson(this);
  }
}

abstract class _ShutterExtraItem implements ShutterExtraItem {
  const factory _ShutterExtraItem({
    required final String name,
    required final int price,
    final int quantity,
  }) = _$ShutterExtraItemImpl;

  factory _ShutterExtraItem.fromJson(Map<String, dynamic> json) =
      _$ShutterExtraItemImpl.fromJson;

  @override
  String get name;
  @override
  int get price;
  @override
  int get quantity;

  /// Create a copy of ShutterExtraItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShutterExtraItemImplCopyWith<_$ShutterExtraItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShutterEstimateResult _$ShutterEstimateResultFromJson(
  Map<String, dynamic> json,
) {
  return _ShutterEstimateResult.fromJson(json);
}

/// @nodoc
mixin _$ShutterEstimateResult {
  ShutterEstimateInput get input => throw _privateConstructorUsedError;
  int get totalAmount => throw _privateConstructorUsedError;
  List<ShutterBreakdownItem> get breakdown =>
      throw _privateConstructorUsedError;
  double get area => throw _privateConstructorUsedError;
  double get weightKg => throw _privateConstructorUsedError;
  String get motorModel => throw _privateConstructorUsedError;
  String get powerSpec => throw _privateConstructorUsedError;
  String get boxSize => throw _privateConstructorUsedError;
  String get bracketType => throw _privateConstructorUsedError;
  String? get slatPriceNote =>
      throw _privateConstructorUsedError; // 추가: 슬라트 계산 근거 (예: 10.5㎡ × 144,000원)
  String get calculatedAt => throw _privateConstructorUsedError;

  /// Serializes this ShutterEstimateResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShutterEstimateResultCopyWith<ShutterEstimateResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShutterEstimateResultCopyWith<$Res> {
  factory $ShutterEstimateResultCopyWith(
    ShutterEstimateResult value,
    $Res Function(ShutterEstimateResult) then,
  ) = _$ShutterEstimateResultCopyWithImpl<$Res, ShutterEstimateResult>;
  @useResult
  $Res call({
    ShutterEstimateInput input,
    int totalAmount,
    List<ShutterBreakdownItem> breakdown,
    double area,
    double weightKg,
    String motorModel,
    String powerSpec,
    String boxSize,
    String bracketType,
    String? slatPriceNote,
    String calculatedAt,
  });

  $ShutterEstimateInputCopyWith<$Res> get input;
}

/// @nodoc
class _$ShutterEstimateResultCopyWithImpl<
  $Res,
  $Val extends ShutterEstimateResult
>
    implements $ShutterEstimateResultCopyWith<$Res> {
  _$ShutterEstimateResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? input = null,
    Object? totalAmount = null,
    Object? breakdown = null,
    Object? area = null,
    Object? weightKg = null,
    Object? motorModel = null,
    Object? powerSpec = null,
    Object? boxSize = null,
    Object? bracketType = null,
    Object? slatPriceNote = freezed,
    Object? calculatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            input: null == input
                ? _value.input
                : input // ignore: cast_nullable_to_non_nullable
                      as ShutterEstimateInput,
            totalAmount: null == totalAmount
                ? _value.totalAmount
                : totalAmount // ignore: cast_nullable_to_non_nullable
                      as int,
            breakdown: null == breakdown
                ? _value.breakdown
                : breakdown // ignore: cast_nullable_to_non_nullable
                      as List<ShutterBreakdownItem>,
            area: null == area
                ? _value.area
                : area // ignore: cast_nullable_to_non_nullable
                      as double,
            weightKg: null == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double,
            motorModel: null == motorModel
                ? _value.motorModel
                : motorModel // ignore: cast_nullable_to_non_nullable
                      as String,
            powerSpec: null == powerSpec
                ? _value.powerSpec
                : powerSpec // ignore: cast_nullable_to_non_nullable
                      as String,
            boxSize: null == boxSize
                ? _value.boxSize
                : boxSize // ignore: cast_nullable_to_non_nullable
                      as String,
            bracketType: null == bracketType
                ? _value.bracketType
                : bracketType // ignore: cast_nullable_to_non_nullable
                      as String,
            slatPriceNote: freezed == slatPriceNote
                ? _value.slatPriceNote
                : slatPriceNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            calculatedAt: null == calculatedAt
                ? _value.calculatedAt
                : calculatedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShutterEstimateInputCopyWith<$Res> get input {
    return $ShutterEstimateInputCopyWith<$Res>(_value.input, (value) {
      return _then(_value.copyWith(input: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ShutterEstimateResultImplCopyWith<$Res>
    implements $ShutterEstimateResultCopyWith<$Res> {
  factory _$$ShutterEstimateResultImplCopyWith(
    _$ShutterEstimateResultImpl value,
    $Res Function(_$ShutterEstimateResultImpl) then,
  ) = __$$ShutterEstimateResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    ShutterEstimateInput input,
    int totalAmount,
    List<ShutterBreakdownItem> breakdown,
    double area,
    double weightKg,
    String motorModel,
    String powerSpec,
    String boxSize,
    String bracketType,
    String? slatPriceNote,
    String calculatedAt,
  });

  @override
  $ShutterEstimateInputCopyWith<$Res> get input;
}

/// @nodoc
class __$$ShutterEstimateResultImplCopyWithImpl<$Res>
    extends
        _$ShutterEstimateResultCopyWithImpl<$Res, _$ShutterEstimateResultImpl>
    implements _$$ShutterEstimateResultImplCopyWith<$Res> {
  __$$ShutterEstimateResultImplCopyWithImpl(
    _$ShutterEstimateResultImpl _value,
    $Res Function(_$ShutterEstimateResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? input = null,
    Object? totalAmount = null,
    Object? breakdown = null,
    Object? area = null,
    Object? weightKg = null,
    Object? motorModel = null,
    Object? powerSpec = null,
    Object? boxSize = null,
    Object? bracketType = null,
    Object? slatPriceNote = freezed,
    Object? calculatedAt = null,
  }) {
    return _then(
      _$ShutterEstimateResultImpl(
        input: null == input
            ? _value.input
            : input // ignore: cast_nullable_to_non_nullable
                  as ShutterEstimateInput,
        totalAmount: null == totalAmount
            ? _value.totalAmount
            : totalAmount // ignore: cast_nullable_to_non_nullable
                  as int,
        breakdown: null == breakdown
            ? _value._breakdown
            : breakdown // ignore: cast_nullable_to_non_nullable
                  as List<ShutterBreakdownItem>,
        area: null == area
            ? _value.area
            : area // ignore: cast_nullable_to_non_nullable
                  as double,
        weightKg: null == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double,
        motorModel: null == motorModel
            ? _value.motorModel
            : motorModel // ignore: cast_nullable_to_non_nullable
                  as String,
        powerSpec: null == powerSpec
            ? _value.powerSpec
            : powerSpec // ignore: cast_nullable_to_non_nullable
                  as String,
        boxSize: null == boxSize
            ? _value.boxSize
            : boxSize // ignore: cast_nullable_to_non_nullable
                  as String,
        bracketType: null == bracketType
            ? _value.bracketType
            : bracketType // ignore: cast_nullable_to_non_nullable
                  as String,
        slatPriceNote: freezed == slatPriceNote
            ? _value.slatPriceNote
            : slatPriceNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        calculatedAt: null == calculatedAt
            ? _value.calculatedAt
            : calculatedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShutterEstimateResultImpl implements _ShutterEstimateResult {
  const _$ShutterEstimateResultImpl({
    required this.input,
    required this.totalAmount,
    required final List<ShutterBreakdownItem> breakdown,
    required this.area,
    required this.weightKg,
    required this.motorModel,
    required this.powerSpec,
    required this.boxSize,
    required this.bracketType,
    this.slatPriceNote,
    required this.calculatedAt,
  }) : _breakdown = breakdown;

  factory _$ShutterEstimateResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShutterEstimateResultImplFromJson(json);

  @override
  final ShutterEstimateInput input;
  @override
  final int totalAmount;
  final List<ShutterBreakdownItem> _breakdown;
  @override
  List<ShutterBreakdownItem> get breakdown {
    if (_breakdown is EqualUnmodifiableListView) return _breakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_breakdown);
  }

  @override
  final double area;
  @override
  final double weightKg;
  @override
  final String motorModel;
  @override
  final String powerSpec;
  @override
  final String boxSize;
  @override
  final String bracketType;
  @override
  final String? slatPriceNote;
  // 추가: 슬라트 계산 근거 (예: 10.5㎡ × 144,000원)
  @override
  final String calculatedAt;

  @override
  String toString() {
    return 'ShutterEstimateResult(input: $input, totalAmount: $totalAmount, breakdown: $breakdown, area: $area, weightKg: $weightKg, motorModel: $motorModel, powerSpec: $powerSpec, boxSize: $boxSize, bracketType: $bracketType, slatPriceNote: $slatPriceNote, calculatedAt: $calculatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShutterEstimateResultImpl &&
            (identical(other.input, input) || other.input == input) &&
            (identical(other.totalAmount, totalAmount) ||
                other.totalAmount == totalAmount) &&
            const DeepCollectionEquality().equals(
              other._breakdown,
              _breakdown,
            ) &&
            (identical(other.area, area) || other.area == area) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.motorModel, motorModel) ||
                other.motorModel == motorModel) &&
            (identical(other.powerSpec, powerSpec) ||
                other.powerSpec == powerSpec) &&
            (identical(other.boxSize, boxSize) || other.boxSize == boxSize) &&
            (identical(other.bracketType, bracketType) ||
                other.bracketType == bracketType) &&
            (identical(other.slatPriceNote, slatPriceNote) ||
                other.slatPriceNote == slatPriceNote) &&
            (identical(other.calculatedAt, calculatedAt) ||
                other.calculatedAt == calculatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    input,
    totalAmount,
    const DeepCollectionEquality().hash(_breakdown),
    area,
    weightKg,
    motorModel,
    powerSpec,
    boxSize,
    bracketType,
    slatPriceNote,
    calculatedAt,
  );

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShutterEstimateResultImplCopyWith<_$ShutterEstimateResultImpl>
  get copyWith =>
      __$$ShutterEstimateResultImplCopyWithImpl<_$ShutterEstimateResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShutterEstimateResultImplToJson(this);
  }
}

abstract class _ShutterEstimateResult implements ShutterEstimateResult {
  const factory _ShutterEstimateResult({
    required final ShutterEstimateInput input,
    required final int totalAmount,
    required final List<ShutterBreakdownItem> breakdown,
    required final double area,
    required final double weightKg,
    required final String motorModel,
    required final String powerSpec,
    required final String boxSize,
    required final String bracketType,
    final String? slatPriceNote,
    required final String calculatedAt,
  }) = _$ShutterEstimateResultImpl;

  factory _ShutterEstimateResult.fromJson(Map<String, dynamic> json) =
      _$ShutterEstimateResultImpl.fromJson;

  @override
  ShutterEstimateInput get input;
  @override
  int get totalAmount;
  @override
  List<ShutterBreakdownItem> get breakdown;
  @override
  double get area;
  @override
  double get weightKg;
  @override
  String get motorModel;
  @override
  String get powerSpec;
  @override
  String get boxSize;
  @override
  String get bracketType;
  @override
  String? get slatPriceNote; // 추가: 슬라트 계산 근거 (예: 10.5㎡ × 144,000원)
  @override
  String get calculatedAt;

  /// Create a copy of ShutterEstimateResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShutterEstimateResultImplCopyWith<_$ShutterEstimateResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ShutterBreakdownItem _$ShutterBreakdownItemFromJson(Map<String, dynamic> json) {
  return _ShutterBreakdownItem.fromJson(json);
}

/// @nodoc
mixin _$ShutterBreakdownItem {
  String get name => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this ShutterBreakdownItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShutterBreakdownItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShutterBreakdownItemCopyWith<ShutterBreakdownItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShutterBreakdownItemCopyWith<$Res> {
  factory $ShutterBreakdownItemCopyWith(
    ShutterBreakdownItem value,
    $Res Function(ShutterBreakdownItem) then,
  ) = _$ShutterBreakdownItemCopyWithImpl<$Res, ShutterBreakdownItem>;
  @useResult
  $Res call({String name, int amount, String? note});
}

/// @nodoc
class _$ShutterBreakdownItemCopyWithImpl<
  $Res,
  $Val extends ShutterBreakdownItem
>
    implements $ShutterBreakdownItemCopyWith<$Res> {
  _$ShutterBreakdownItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShutterBreakdownItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amount: null == amount
                ? _value.amount
                : amount // ignore: cast_nullable_to_non_nullable
                      as int,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShutterBreakdownItemImplCopyWith<$Res>
    implements $ShutterBreakdownItemCopyWith<$Res> {
  factory _$$ShutterBreakdownItemImplCopyWith(
    _$ShutterBreakdownItemImpl value,
    $Res Function(_$ShutterBreakdownItemImpl) then,
  ) = __$$ShutterBreakdownItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, int amount, String? note});
}

/// @nodoc
class __$$ShutterBreakdownItemImplCopyWithImpl<$Res>
    extends _$ShutterBreakdownItemCopyWithImpl<$Res, _$ShutterBreakdownItemImpl>
    implements _$$ShutterBreakdownItemImplCopyWith<$Res> {
  __$$ShutterBreakdownItemImplCopyWithImpl(
    _$ShutterBreakdownItemImpl _value,
    $Res Function(_$ShutterBreakdownItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShutterBreakdownItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? note = freezed,
  }) {
    return _then(
      _$ShutterBreakdownItemImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amount: null == amount
            ? _value.amount
            : amount // ignore: cast_nullable_to_non_nullable
                  as int,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShutterBreakdownItemImpl implements _ShutterBreakdownItem {
  const _$ShutterBreakdownItemImpl({
    required this.name,
    required this.amount,
    this.note,
  });

  factory _$ShutterBreakdownItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShutterBreakdownItemImplFromJson(json);

  @override
  final String name;
  @override
  final int amount;
  @override
  final String? note;

  @override
  String toString() {
    return 'ShutterBreakdownItem(name: $name, amount: $amount, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShutterBreakdownItemImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amount, note);

  /// Create a copy of ShutterBreakdownItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShutterBreakdownItemImplCopyWith<_$ShutterBreakdownItemImpl>
  get copyWith =>
      __$$ShutterBreakdownItemImplCopyWithImpl<_$ShutterBreakdownItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShutterBreakdownItemImplToJson(this);
  }
}

abstract class _ShutterBreakdownItem implements ShutterBreakdownItem {
  const factory _ShutterBreakdownItem({
    required final String name,
    required final int amount,
    final String? note,
  }) = _$ShutterBreakdownItemImpl;

  factory _ShutterBreakdownItem.fromJson(Map<String, dynamic> json) =
      _$ShutterBreakdownItemImpl.fromJson;

  @override
  String get name;
  @override
  int get amount;
  @override
  String? get note;

  /// Create a copy of ShutterBreakdownItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShutterBreakdownItemImplCopyWith<_$ShutterBreakdownItemImpl>
  get copyWith => throw _privateConstructorUsedError;
}
