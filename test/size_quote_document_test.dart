import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SizeQuoteSeed seed() => const SizeQuoteSeed(
    categoryId: 'cat',
    categoryName: '스피드도어',
    modelId: 'm1',
    modelName: 'S-3000',
    widthMm: 4000,
    heightMm: 4000,
    standardPrice: 1000000,
  );

  test('표준단가에 %·금액을 더해 판매단가를 만든다', () {
    expect(
      sizeQuoteApplyMarkup(
        standardPrice: 1000000,
        markupType: kSizeQuoteMarkupPercent,
        markupValue: 10,
      ),
      1100000,
    );
    expect(
      sizeQuoteApplyMarkup(
        standardPrice: 1000000,
        markupType: kSizeQuoteMarkupAmount,
        markupValue: 150000,
      ),
      1150000,
    );
    expect(
      sizeQuoteApplyMarkup(
        standardPrice: 1000000,
        markupType: kSizeQuoteMarkupNone,
        markupValue: 10,
      ),
      1000000,
    );
  });

  test('본체 라인은 표준단가와 마진을 따라간다', () {
    final doc = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    expect(doc.lines.single.isProduct, isTrue);
    expect(doc.sellingUnitPrice, 1000000);
    expect(doc.total, 1000000);

    final marked = doc.copyWith(
      markupType: kSizeQuoteMarkupPercent,
      markupValue: 10,
      lines: sizeQuoteSyncProductLine(
        lines: doc.lines,
        seed: seed(),
        quantity: 1,
        markupType: kSizeQuoteMarkupPercent,
        markupValue: 10,
      ),
    );
    expect(marked.sellingUnitPrice, 1100000);
    expect(marked.lines.single.unitPrice, 1100000);
    expect(marked.total, 1100000);
  });

  test('네고는 빨간색 요약과 최종 합계에 반영된다', () {
    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    expect(base.copyWith(negoPercent: 10).total, 900000);
    expect(base.copyWith(negoPercent: 10).negoSummary, contains('10%'));
    expect(base.copyWith(negoAmount: 50000).total, 950000);
    expect(base.copyWith(negoAmount: 50000).hasNego, isTrue);
  });

  test('목표 총액에 맞추면 기타 금액 조정 라인으로 나머지를 채운다', () {
    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    final fitted = sizeQuoteFitToTarget(base, 1300000);
    expect(fitted.targetTotal, 1300000);
    expect(fitted.total, 1300000);
    expect(
      fitted.lines.any((e) => e.name == kSizeQuoteFitLineName),
      isTrue,
    );
    expect(fitted.lines.last.kind, kSizeQuoteKindOther);
    expect(fitted.lines.last.amount, 300000);
  });

  test('네고가 있어도 목표 총액 최종값이 맞는다', () {
    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07').copyWith(
      negoPercent: 10,
    );
    final fitted = sizeQuoteFitToTarget(base, 990000);
    expect(fitted.total, 990000);
  });

  test('같은 모델 비슷한 사이즈 견적을 거리순으로 고른다', () {
    const same = SizeQuoteDocument(
      id: 'a',
      customerName: '김현장',
      site: '수성',
      ymd: '2026-09-01',
      modelId: 'm1',
      modelName: 'S-3000',
      widthMm: 4000,
      heightMm: 4000,
      createdBy: '홍길동',
      lines: [
        SizeQuoteLine(name: 'S-3000', qty: 1, unitPrice: 1200000, isProduct: true),
      ],
    );
    const near = SizeQuoteDocument(
      id: 'b',
      customerName: '이현장',
      site: '달서',
      ymd: '2026-09-02',
      modelId: 'm1',
      widthMm: 4300,
      heightMm: 4000,
      createdBy: '박영업',
      lines: [
        SizeQuoteLine(name: 'S-3000', qty: 1, unitPrice: 1250000, isProduct: true),
      ],
    );
    const otherModel = SizeQuoteDocument(
      id: 'c',
      customerName: '최현장',
      ymd: '2026-09-03',
      modelId: 'm2',
      widthMm: 4000,
      heightMm: 4000,
      lines: [
        SizeQuoteLine(name: '다른모델', qty: 1, unitPrice: 900000),
      ],
    );
    const far = SizeQuoteDocument(
      id: 'd',
      customerName: '정현장',
      ymd: '2026-09-04',
      modelId: 'm1',
      widthMm: 6000,
      heightMm: 6000,
      lines: [
        SizeQuoteLine(name: 'S-3000', qty: 1, unitPrice: 2000000),
      ],
    );
    final rows = sizeQuoteSimilarOf(
      all: [far, near, same, otherModel],
      modelId: 'm1',
      widthMm: 4000,
      heightMm: 4000,
    );
    expect(rows.map((e) => e.id).toList(), ['a', 'b']);
    expect(rows.first.createdBy, '홍길동');
    expect(rows.first.total, 1200000);
  });

  test('현장명·날짜·금액으로 검색한다', () {
    final doc = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07').copyWith(
      customerName: '김현장',
      site: '수성 한빛',
      createdBy: '홍길동',
    );
    expect(sizeQuoteMatches(doc, '수성'), isTrue);
    expect(sizeQuoteMatches(doc, '2026-09'), isTrue);
    expect(sizeQuoteMatches(doc, '20260907'), isTrue);
    expect(sizeQuoteMatches(doc, 'S-3000'), isTrue);
    expect(sizeQuoteMatches(doc, '홍길동'), isTrue);
    expect(sizeQuoteMatches(doc, '없는현장'), isFalse);
  });

  test('메인·부자재·기타 라벨을 구분한다', () {
    expect(sizeQuoteKindLabel(kSizeQuoteKindMain), '메인');
    expect(sizeQuoteKindLabel(kSizeQuoteKindAccessory), '부자재');
    expect(sizeQuoteKindLabel(kSizeQuoteKindOther), '기타');
    expect(normalizeSizeQuoteKind('부자재'), kSizeQuoteKindAccessory);
  });
}
