import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';

const kShutterQuoteCategoryId = 'shutter';
const kShutterQuoteCategoryName = '셔터';

String shutterQuoteModelId(ShutterType type) => 'shutter_${type.name}';

String _breakdownKind(ShutterBreakdownItem item) {
  final n = item.name;
  if (n.contains('시공') || n.contains('장비') || n.contains('이익')) {
    return kSizeQuoteKindOther;
  }
  if (ShutterCalculator.isMaterialCostItem(item) && !n.contains('스라트')) {
    return kSizeQuoteKindAccessory;
  }
  return kSizeQuoteKindAccessory;
}

/// 셔터 견적기 결과 → 표준단가 견적서 초안.
({
  SizeQuoteSeed seed,
  List<SizeQuoteLine> extraLines,
  String note,
  int quantity,
})
sizeQuoteDraftFromShutter({
  required ShutterEstimateResult result,
  String? companyName,
}) {
  final type = result.input.type;
  final typeLabel = QuoterTypeStyle.label(type);
  final widthMm = result.input.widthMm.round();
  final heightMm = result.input.heightMm.round();
  final qty = result.input.quantity <= 0 ? 1 : result.input.quantity;
  final slatItems = result.breakdown.where((e) => e.name.contains('스라트')).toList();
  final slat = slatItems.fold<int>(0, (sum, e) => sum + e.amount);
  final fallbackProduct = result.breakdown.where((e) => e.amount > 0).firstOrNull;
  final productPrice = slat > 0
      ? slat
      : (fallbackProduct?.amount ?? result.totalAmount);
  final seed = SizeQuoteSeed(
    categoryId: kShutterQuoteCategoryId,
    categoryName: kShutterQuoteCategoryName,
    modelId: shutterQuoteModelId(type),
    modelName: typeLabel,
    widthMm: widthMm,
    heightMm: heightMm,
    standardPrice: productPrice,
  );

  final extra = <SizeQuoteLine>[];
  for (final item in result.breakdown) {
    if (item.amount <= 0) continue;
    if (slat > 0 && item.name.contains('스라트')) continue;
    if (slat <= 0 &&
        fallbackProduct != null &&
        item.name == fallbackProduct.name &&
        item.amount == fallbackProduct.amount) {
      continue;
    }
    extra.add(
      SizeQuoteLine(
        name: item.name,
        spec: (item.note ?? '').trim(),
        unit: '식',
        qty: 1,
        unitPrice: item.amount,
        note: (item.note ?? '').trim(),
        kind: _breakdownKind(item),
      ),
    );
  }
  for (final item in result.input.extraItems) {
    final amount = item.price * (item.quantity <= 0 ? 1 : item.quantity);
    if (amount <= 0) continue;
    extra.add(
      SizeQuoteLine(
        name: item.name,
        spec: item.quantity > 1 ? '${item.quantity}개' : '',
        unit: '식',
        qty: 1,
        unitPrice: amount,
        kind: kSizeQuoteKindAccessory,
      ),
    );
  }

  final note = [
    if ((companyName ?? '').trim().isNotEmpty) '적용 업체: ${companyName!.trim()}',
    if (result.area > 0) '면적 ${result.area.toStringAsFixed(2)}㎡',
    if (result.motorModel.trim().isNotEmpty) '모터 ${result.motorModel.trim()}',
    if (result.powerSpec.trim().isNotEmpty) result.powerSpec.trim(),
    if (result.boxSize.trim().isNotEmpty) '셔터박스 ${result.boxSize.trim()}',
    if (result.bracketType.trim().isNotEmpty)
      '브라켓 ${result.bracketType.trim()}',
    if ((result.input.memo ?? '').trim().isNotEmpty) result.input.memo!.trim(),
  ].join('\n');

  return (seed: seed, extraLines: extra, note: note, quantity: qty);
}
