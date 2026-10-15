import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_export.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_paper.dart';
import 'package:flutter/material.dart';
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

  test('PREMIUM 공사명은 모델이 아니라 상위 분류다', () {
    const premium = SizeQuoteSeed(
      categoryId: 'cat',
      categoryName: '스피드도어',
      modelId: 'p',
      modelName: 'PREMIUM',
      widthMm: 3000,
      heightMm: 3000,
      standardPrice: 6800000,
    );
    final doc = sizeQuoteFromSeed(seed: premium, ymd: '2026-09-28');
    expect(doc.workName, '스피드도어 설치 공사');
    expect(
      sizeQuoteResolvedWorkName(
        workName: 'PREMIUM 설치 공사',
        categoryName: '스피드도어',
        modelName: 'PREMIUM',
      ),
      '스피드도어 설치 공사',
    );
    expect(
      sizeQuoteResolvedWorkName(
        workName: '현장 맞춤 공사',
        categoryName: '스피드도어',
        modelName: 'PREMIUM',
      ),
      '현장 맞춤 공사',
    );
    expect(sizeQuoteStaffLabel(name: '김경덕', title: '이사'), '김경덕 이사');
    expect(sizeQuoteStaffLabel(name: '김경덕', title: '팀원'), '김경덕');
    expect(
      sizeQuoteManagerLine('김경덕 이사', '01012345678'),
      '김경덕 이사 (H.P 010-1234-5678)',
    );
    expect(
      sizeQuoteManagerLine('김경덕 (H.P 010-1234-5678)', '01099998888'),
      '김경덕 (H.P 010-1234-5678)',
    );
  });

  testWidgets('견적서 용지에 상위 분류 공사명과 로그인한 담당자가 보인다', (tester) async {
    const doc = SizeQuoteDocument(
      id: '1',
      customerName: '김현장',
      ymd: '2026-09-28',
      categoryName: '스피드도어',
      modelName: 'PREMIUM',
      workName: 'PREMIUM 설치 공사',
      createdBy: '옛작성자',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: SizeQuotePaper(
            doc: doc,
            managerName: '김경덕',
            branchName: '대구지사',
          ),
        ),
      ),
    );
    expect(find.text('스피드도어 설치 공사'), findsOneWidget);
    expect(find.text('김경덕'), findsOneWidget);
    expect(find.text('담당자 : 김경덕'), findsOneWidget);
    expect(find.text('코아드  대구지사'), findsOneWidget);
    expect(find.textContaining('달성군 논공읍'), findsOneWidget);
    expect(find.textContaining('coaddg@coaddoor.com'), findsOneWidget);
    final address = tester.widget<Text>(find.textContaining('주소 :'));
    expect(address.maxLines, 1);
    expect(address.softWrap, isFalse);
    final fax = tester.widget<Text>(find.text('FAX : 0505-182-5567'));
    expect(fax.maxLines, 1);
    expect(fax.softWrap, isFalse);
    expect(find.text('PREMIUM 설치 공사'), findsNothing);
  });

  test('견적서 전체 보기는 오른쪽 끝까지 화면 안에 넣는다', () {
    const view = Size(360, 520);
    const paper = Size(560, 980);
    final matrix = sizeQuoteFitMatrix(view: view, paper: paper);
    final scale = matrix.getMaxScaleOnAxis();
    final dx = matrix.getTranslation().x;
    expect(scale, closeTo(520 / 980, 0.0001));
    expect(dx, greaterThan(0));
    expect(dx + paper.width * scale, lessThanOrEqualTo(view.width + 0.01));
    expect(dx, greaterThanOrEqualTo(-0.01));
  });

  test('견적서 보기는 맞춘 크기보다 줄일 수 있다', () {
    expect(sizeQuoteViewerMinScale(0.5), closeTo(0.175, 0.0001));
    expect(sizeQuoteViewerMinScale(0.5), lessThan(0.5));
    expect(sizeQuoteViewerMinScale(0.08), 0.05);
    expect(sizeQuoteViewerMinScale(0.02), 0.02);
  });

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
    expect(
      sizeQuoteApplyMarkup(standardPrice: 1000000, percent: 5, amount: 200000),
      1250000,
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

  test('네고는 5%·20만원 단위로 올리고 최종이 그대로면 변경 없다', () {
    expect(sizeQuoteStepPercent(0, 5), 5);
    expect(sizeQuoteStepPercent(5, -5), 0);
    expect(sizeQuoteStepPercent(98, 5), 100);
    expect(sizeQuoteStepPercent(0, -5, min: -100), -5);
    expect(sizeQuoteStepAmount(0, -200000, min: -1000000), -200000);
    expect(sizeQuoteStepAmount(0, 200000, max: 1000000), 200000);
    expect(sizeQuoteStepAmount(200000, -200000), 0);
    expect(sizeQuoteStepAmount(900000, 200000, max: 1000000), 1000000);

    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    expect(base.finalUnchanged, isTrue);
    expect(base.finalChangeLabel, '변경 없음');
    final cut = base.copyWith(negoAmount: 200000);
    expect(cut.finalUnchanged, isFalse);
    expect(cut.finalChangeLabel, '변경 −200,000원');
  });

  test('네고는 빨간색 요약과 최종 합계에 반영된다', () {
    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    expect(base.copyWith(negoPercent: 10).total, 900000);
    expect(base.copyWith(negoPercent: 10).negoSummary, contains('10%'));
    expect(base.copyWith(negoAmount: 50000).total, 950000);
    expect(base.copyWith(negoAmount: 50000).hasNego, isTrue);
  });

  test('세부견적은 목표 단가를 본체·센서·시공비·운반장비대로 나누고 표준단가와 차이를 낸다', () {
    expect(
      sizeQuoteDetailBodyUnit(
        targetUnit: 4800000,
        sensor: kSizeQuoteDefaultSensor,
        install: kSizeQuoteDefaultInstall,
        transport: kSizeQuoteDefaultTransport,
      ),
      3500000,
    );
    expect(
      sizeQuotePriceGapLabel(standardPrice: 5200000, targetUnit: 4800000),
      '−400,000원 (−7.7%)',
    );
    expect(
      sizeQuotePriceGapLabel(standardPrice: 1000000, targetUnit: 1000000),
      '차이 없음',
    );
    expect(
      sizeQuotePriceGapLabel(standardPrice: 1000000, targetUnit: 1250000),
      '+250,000원 (+25%)',
    );

    final lines = sizeQuoteDetailLines(
      seed: seed(),
      quantity: 2,
      targetUnit: 900000,
      sensor: 100000,
      install: 50000,
      transport: 50000,
    );
    expect(lines.map((e) => e.name).toList(), [
      'S-3000 본체',
      '센서',
      '시공비',
      '운반장비대',
    ]);
    expect(lines.first.unitPrice, 700000);
    expect(lines.first.detailRole, kSizeQuoteDetailBody);
    expect(lines.first.isProduct, isTrue);
    expect(lines[1].name, '센서');
    expect(lines[1].qty, 2);
    expect(lines[1].amount, 200000);
    expect(lines[2].qty, 2);
    expect(lines[2].amount, 100000);
    expect(lines[3].qty, 2);
    expect(lines[3].amount, 100000);
    expect(
      lines.fold<int>(0, (sum, line) => sum + (line.unitPrice ?? 0)),
      900000,
    );

    final again = SizeQuoteLine.fromJson(lines[2].toJson());
    expect(again.detailRole, kSizeQuoteDetailInstall);
    expect(again.name, '시공비');

    final doc = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07').copyWith(
      quantity: 2,
      markupPercent: 0,
      markupAmount: -100000,
      lines: [
        ...lines,
        const SizeQuoteLine(
          name: '옵션',
          qty: 1,
          unitPrice: 10000,
          kind: kSizeQuoteKindAccessory,
        ),
      ],
    );
    expect(doc.isDetailQuote, isTrue);
    expect(doc.total, 1810000);
    expect(doc.baselineTotal, 2010000);
    expect(doc.finalDelta, -200000);
    expect(doc.finalChangeLabel, '변경 −200,000원');

    final zeroSensor = sizeQuoteDetailLines(
      seed: seed(),
      quantity: 1,
      targetUnit: 1000000,
      sensor: 0,
      install: 200000,
      transport: 0,
    );
    expect(zeroSensor.map((e) => e.name).toList(), ['S-3000 본체', '시공비']);
    expect(sizeQuoteLineShowsOnPaper(zeroSensor.first), isTrue);
  });

  test('2세트 세부견적은 센서·시공비·운반장비대 수량이 2이고 금액이 두 배다', () {
    final lines = sizeQuoteDetailLines(
      seed: seed(),
      quantity: 2,
      targetUnit: 4800000,
      sensor: kSizeQuoteDefaultSensor,
      install: kSizeQuoteDefaultInstall,
      transport: kSizeQuoteDefaultTransport,
    );
    final sensor = lines.firstWhere(
      (e) => e.detailRole == kSizeQuoteDetailSensor,
    );
    final install = lines.firstWhere(
      (e) => e.detailRole == kSizeQuoteDetailInstall,
    );
    final transport = lines.firstWhere(
      (e) => e.detailRole == kSizeQuoteDetailTransport,
    );
    expect(sensor.qty, 2);
    expect(sensor.unitPrice, 200000);
    expect(sensor.amount, 400000);
    expect(install.qty, 2);
    expect(install.amount, 1600000);
    expect(transport.qty, 2);
    expect(transport.amount, 600000);
    expect(lines.first.qty, 2);
    expect(lines.first.spec, '4000×4000');
    expect(sensor.spec, '4000×4000');
  });

  test('같은 모델의 다른 사이즈는 한 견적에서 각자 수량으로 계산된다', () {
    final first = sizeQuoteDetailLines(
      seed: seed(),
      quantity: 2,
      targetUnit: 1300000,
      sensor: 200000,
      install: 800000,
      transport: 300000,
    );
    final second = sizeQuoteSizeLines(
      modelName: 'S-3000',
      widthMm: 3000,
      heightMm: 2500,
      quantity: 1,
      standardPrice: 2400000,
      detail: true,
      unitPrice: 2400000,
      sensor: 200000,
      install: 800000,
      transport: 300000,
    );
    final doc = sizeQuoteFromSeed(
      seed: seed(),
      ymd: '2026-09-07',
    ).copyWith(quantity: 2, lines: [...first, ...second]);
    final sizes = sizeQuoteSizesOf(doc);
    expect(sizes, hasLength(2));
    expect(sizes.first.label, '4000×4000');
    expect(sizes.first.quantity, 2);
    expect(sizes.first.sensor, 200000);
    expect(sizes.first.standardPrice, 1000000);
    expect(sizes[1].label, '3000×2500');
    expect(sizes[1].quantity, 1);
    expect(sizes[1].standardPrice, 2400000);
    expect(sizes[1].sellingUnit, 2400000);
    expect(doc.total, 5000000);
    expect(doc.baselineTotal, 4400000);
    expect(sizeQuoteSizeListLabel(doc), '4000×4000 2SET · 3000×2500');

    final again = SizeQuoteDocument.fromJson(doc.toJson());
    expect(sizeQuoteSizesOf(again)[1].widthMm, 3000);
    expect(sizeQuoteSizesOf(again)[1].standardPrice, 2400000);
    expect(
      again.lines
          .firstWhere((e) => e.detailRole == kSizeQuoteDetailSensor)
          .amount,
      400000,
    );
  });

  test('예전 세부 줄은 규격이 비어도 대표 사이즈로 묶인다', () {
    const legacy = SizeQuoteDocument(
      id: 'old',
      customerName: '김현장',
      ymd: '2026-09-07',
      modelName: 'S-3000',
      widthMm: 4000,
      heightMm: 4000,
      quantity: 2,
      standardPrice: 1000000,
      lines: [
        SizeQuoteLine(
          name: 'S-3000 본체',
          spec: '4000×4000',
          unit: 'SET',
          qty: 2,
          unitPrice: 700000,
          isProduct: true,
          detailRole: kSizeQuoteDetailBody,
        ),
        SizeQuoteLine(
          name: '센서',
          unit: 'SET',
          qty: 2,
          unitPrice: 100000,
          detailRole: kSizeQuoteDetailSensor,
        ),
        SizeQuoteLine(
          name: '시공비',
          unit: '식',
          qty: 2,
          unitPrice: 50000,
          detailRole: kSizeQuoteDetailInstall,
        ),
        SizeQuoteLine(
          name: '운반장비대',
          unit: '식',
          qty: 2,
          unitPrice: 50000,
          detailRole: kSizeQuoteDetailTransport,
        ),
      ],
    );
    final sizes = sizeQuoteSizesOf(legacy);
    expect(sizes, hasLength(1));
    expect(sizes.first.quantity, 2);
    expect(sizes.first.sensor, 100000);
    expect(sizes.first.sellingUnit, 900000);
    expect(legacy.lines[1].amount, 200000);
    expect(sizeQuoteSizeListLabel(legacy), '4000×4000');
  });

  testWidgets('세부견적 용지에는 나눈 항목만 보이고 표준단가는 찍지 않는다', (tester) async {
    final lines = sizeQuoteDetailLines(
      seed: seed(),
      quantity: 1,
      targetUnit: 4800000,
      sensor: 300000,
      install: 250000,
      transport: 150000,
    );
    final doc = SizeQuoteDocument(
      id: 'detail',
      customerName: '김현장',
      ymd: '2026-10-15',
      categoryName: '스피드도어',
      modelName: 'S-3000',
      widthMm: 4000,
      heightMm: 4000,
      standardPrice: 5200000,
      quantity: 1,
      lines: lines,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(child: SizeQuotePaper(doc: doc)),
      ),
    );
    expect(find.text('S-3000 본체'), findsOneWidget);
    expect(find.text('센서'), findsOneWidget);
    expect(find.text('시공비'), findsOneWidget);
    expect(find.text('운반장비대'), findsOneWidget);
    expect(find.textContaining('표준단가'), findsNothing);
    expect(doc.total, 4800000);
  });

  test('목표 총액에 맞추면 기타 금액 조정 라인으로 나머지를 채운다', () {
    final base = sizeQuoteFromSeed(seed: seed(), ymd: '2026-09-07');
    final fitted = sizeQuoteFitToTarget(base, 1300000);
    expect(fitted.targetTotal, 1300000);
    expect(fitted.total, 1300000);
    expect(fitted.lines.any((e) => e.name == kSizeQuoteFitLineName), isTrue);
    expect(fitted.lines.last.kind, kSizeQuoteKindOther);
    expect(fitted.lines.last.amount, 300000);
  });

  test('네고가 있어도 목표 총액 최종값이 맞는다', () {
    final base = sizeQuoteFromSeed(
      seed: seed(),
      ymd: '2026-09-07',
    ).copyWith(negoPercent: 10);
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
        SizeQuoteLine(
          name: 'S-3000',
          qty: 1,
          unitPrice: 1200000,
          isProduct: true,
        ),
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
        SizeQuoteLine(
          name: 'S-3000',
          qty: 1,
          unitPrice: 1250000,
          isProduct: true,
        ),
      ],
    );
    const otherModel = SizeQuoteDocument(
      id: 'c',
      customerName: '최현장',
      ymd: '2026-09-03',
      modelId: 'm2',
      widthMm: 4000,
      heightMm: 4000,
      lines: [SizeQuoteLine(name: '다른모델', qty: 1, unitPrice: 900000)],
    );
    const far = SizeQuoteDocument(
      id: 'd',
      customerName: '정현장',
      ymd: '2026-09-04',
      modelId: 'm1',
      widthMm: 6000,
      heightMm: 6000,
      lines: [SizeQuoteLine(name: 'S-3000', qty: 1, unitPrice: 2000000)],
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
    final doc = sizeQuoteFromSeed(
      seed: seed(),
      ymd: '2026-09-07',
    ).copyWith(customerName: '김현장', site: '수성 한빛', createdBy: '홍길동');
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
