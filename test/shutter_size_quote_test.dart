import 'package:coad_customer_calls/features/quoter/shutter_size_quote.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('셔터 견적 결과는 본체·부자재·시공으로 견적서 초안이 된다', () {
    const result = ShutterEstimateResult(
      input: ShutterEstimateInput(
        type: ShutterType.doubleExtrusion,
        widthMm: 4000,
        heightMm: 4000,
        quantity: 1,
        extraItems: [
          ShutterExtraItem(name: '리모컨', price: 30000, quantity: 2),
        ],
      ),
      totalAmount: 1710000,
      breakdown: [
        ShutterBreakdownItem(name: '스라트 (본체)', amount: 810000, note: '10㎡ × 81,000원'),
        ShutterBreakdownItem(name: '시공 예상 비용', amount: 800000),
        ShutterBreakdownItem(name: '모터', amount: 400000, note: 'KEM-500'),
        ShutterBreakdownItem(name: '장비대', amount: 200000),
      ],
      area: 10,
      weightKg: 100,
      motorModel: 'KEM-500',
      powerSpec: '1000W',
      boxSize: '300',
      bracketType: 'KEM-500B',
      calculatedAt: '2026-09-09 12:00',
    );

    final draft = sizeQuoteDraftFromShutter(
      result: result,
      companyName: '코아드',
    );

    expect(draft.seed.categoryName, '셔터');
    expect(draft.seed.modelName, '이중압출');
    expect(draft.seed.widthMm, 4000);
    expect(draft.seed.heightMm, 4000);
    expect(draft.seed.standardPrice, 810000);

    final product = sizeQuoteProductLine(seed: draft.seed);
    expect(product.isProduct, isTrue);
    expect(product.kind, kSizeQuoteKindMain);

    expect(draft.extraLines.any((e) => e.name.contains('시공')), isTrue);
    expect(
      draft.extraLines.firstWhere((e) => e.name.contains('시공')).kind,
      kSizeQuoteKindOther,
    );
    expect(
      draft.extraLines.firstWhere((e) => e.name == '모터').kind,
      kSizeQuoteKindAccessory,
    );
    expect(draft.extraLines.any((e) => e.name == '리모컨'), isTrue);
    expect(draft.note, contains('적용 업체: 코아드'));
    expect(draft.note, contains('KEM-500'));
  });
}
