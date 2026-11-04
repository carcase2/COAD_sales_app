import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_draft_store.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_product_pick.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const speed = SizeQuoteSeed(
    categoryId: 'cat',
    categoryName: '스피드도어',
    modelId: 'm1',
    modelName: 'S-3000',
    widthMm: 4000,
    heightMm: 4000,
    standardPrice: 1000000,
  );
  const shutter = SizeQuoteSeed(
    categoryId: 'shutter',
    categoryName: '셔터',
    modelId: 'shutter_doubleExtrusion',
    modelName: '이중압출',
    widthMm: 5000,
    heightMm: 4000,
    standardPrice: 2000000,
  );

  test('빈 제품과 셔터 제품을 알아본다', () {
    expect(kSizeQuoteEmptySeed.isEmpty, isTrue);
    expect(speed.isEmpty, isFalse);
    expect(speed.isShutter, isFalse);
    expect(shutter.isShutter, isTrue);
  });

  test('직접 입력은 붙일 줄이 없다', () {
    expect(
      sizeQuoteAddedProductLines(const SizeQuoteProductPick.manual()),
      isEmpty,
    );
  });

  test('두 번째 표준단가 제품은 표준가 1줄로, 사이즈 묶음에 안 섞인다', () {
    final lines = sizeQuoteAddedProductLines(
      const SizeQuoteProductPick(
        source: SizeQuoteProductSource.standard,
        seed: speed,
        quantity: 2,
      ),
    );
    expect(lines, hasLength(1));
    final line = lines.single;
    expect(line.name, 'S-3000');
    expect(line.spec, '4000×4000');
    expect(line.qty, 2);
    expect(line.unitPrice, 1000000);
    expect(line.isProduct, isFalse);
    expect(line.kind, kSizeQuoteKindMain);
    expect(sizeQuoteLineIsExtra(line), isTrue);

    // 대표 제품이 있는 견적서에 붙여도 사이즈 목록은 대표 하나다.
    final doc = sizeQuoteFromSeed(seed: shutter, ymd: '2026-11-04');
    final merged = doc.copyWith(lines: [...doc.lines, ...lines]);
    expect(sizeQuoteSizesOf(merged), hasLength(1));
    expect(merged.total, doc.total + 2000000);
  });

  test('두 번째 셔터는 스라트와 부자재를 합친 1SET', () {
    final lines = sizeQuoteAddedProductLines(
      const SizeQuoteProductPick(
        source: SizeQuoteProductSource.shutter,
        seed: shutter,
        extraLines: [
          SizeQuoteLine(name: '모터', unit: '식', unitPrice: 400000),
          SizeQuoteLine(name: '시공비', unit: '식', unitPrice: 800000),
        ],
        note: '적용 업체: A\n면적 20.00㎡',
      ),
    );
    final line = lines.single;
    expect(line.name, '셔터 이중압출');
    expect(line.unitPrice, 3200000);
    expect(line.note, '적용 업체: A · 면적 20.00㎡');
  });

  group('임시저장', () {
    SizeQuoteDocument doc(String id, {String name = '홍길동'}) =>
        sizeQuoteFromSeed(
          seed: speed,
          ymd: '2026-11-04',
          id: id,
        ).copyWith(customerName: name);

    test('넣고 다시 읽고, 같은 견적은 덮어쓰고 최근 것이 앞에 온다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SizeQuoteDraftStore(await SharedPreferences.getInstance());
      await store.put(SizeQuoteDraft(doc: doc('a'), savedAt: '1'));
      await store.put(
        SizeQuoteDraft(doc: doc('b'), savedAt: '2', isNew: false),
      );
      await store.put(
        SizeQuoteDraft(
          doc: doc('a', name: '김철수'),
          savedAt: '3',
        ),
      );
      final items = store.load();
      expect(items.map((e) => e.doc.id), ['a', 'b']);
      expect(items.first.doc.customerName, '김철수');
      expect(items.first.doc.lines, isNotEmpty);
      expect(items[1].isNew, isFalse);

      await store.remove('a');
      expect(store.load().map((e) => e.doc.id), ['b']);
    });

    test('최대 개수를 넘으면 오래된 것부터 버린다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SizeQuoteDraftStore(await SharedPreferences.getInstance());
      for (var i = 0; i < SizeQuoteDraftStore.limit + 3; i++) {
        await store.put(SizeQuoteDraft(doc: doc('d$i'), savedAt: '$i'));
      }
      final items = store.load();
      expect(items, hasLength(SizeQuoteDraftStore.limit));
      expect(items.first.doc.id, 'd${SizeQuoteDraftStore.limit + 2}');
    });
  });
}
