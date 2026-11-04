import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:intl/intl.dart';

/// 견적서에 넣을 제품을 어디서 골랐는지.
enum SizeQuoteProductSource { standard, shutter, manual }

/// 「제품 고르기」 결과. 표준단가 모델·셔터 산출·직접 입력 중 하나.
class SizeQuoteProductPick {
  const SizeQuoteProductPick({
    required this.source,
    this.seed = kSizeQuoteEmptySeed,
    this.extraLines = const [],
    this.note = '',
    this.quantity = 1,
  });

  const SizeQuoteProductPick.manual()
    : this(source: SizeQuoteProductSource.manual);

  final SizeQuoteProductSource source;
  final SizeQuoteSeed seed;

  /// 셔터 산출의 스라트 밖 항목(모터·시공 등).
  final List<SizeQuoteLine> extraLines;
  final String note;
  final int quantity;

  bool get isManual => source == SizeQuoteProductSource.manual;
}

/// 이미 제품이 있는 견적서에 두 번째 제품을 넣을 때의 줄.
/// 대표 제품·사이즈 묶음과 섞이지 않게 제품 표시(isProduct) 없이 한 줄로 넣는다.
/// 셔터는 스라트와 부자재를 합친 1SET 금액이다.
List<SizeQuoteLine> sizeQuoteAddedProductLines(SizeQuoteProductPick pick) {
  if (pick.isManual) return const [];
  final seed = pick.seed;
  final qty = pick.quantity <= 0 ? 1 : pick.quantity;
  final spec = seed.widthMm > 0 && seed.heightMm > 0
      ? '${seed.widthMm}×${seed.heightMm}'
      : '';
  if (pick.source == SizeQuoteProductSource.shutter) {
    final extras = pick.extraLines.fold<int>(0, (sum, e) => sum + e.amount);
    final perSet = seed.standardPrice + extras;
    final name = seed.modelName.contains('셔터')
        ? seed.modelName
        : '셔터 ${seed.modelName}'.trim();
    return [
      SizeQuoteLine(
        name: name,
        spec: spec,
        unit: 'SET',
        qty: qty,
        unitPrice: perSet,
        kind: kSizeQuoteKindMain,
        note: pick.note
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join(' · '),
      ),
    ];
  }
  final won = NumberFormat('#,###');
  return [
    SizeQuoteLine(
      name: seed.modelName,
      spec: spec,
      unit: 'SET',
      qty: qty,
      unitPrice: seed.standardPrice,
      kind: kSizeQuoteKindMain,
      note: seed.standardPrice > 0
          ? '표준단가 ${won.format(seed.standardPrice)}원'
          : '',
    ),
  ];
}
