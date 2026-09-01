import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportUnitPriceItem item({
    String name = '모터',
    String spec = '800N',
    int? price = 85000,
    String note = '유상',
    String updatedByName = '',
  }) => SupportUnitPriceItem(
    id: '1',
    name: name,
    spec: spec,
    price: price,
    note: note,
    updatedByName: updatedByName,
  );

  SupportUnitPriceChangeLog log({
    String action = 'update',
    String itemName = '모터',
    String summary = '모터 · 단가 85,000원 → 90,000원',
    String userName = '김경덕',
    int? oldPrice = 85000,
    int? newPrice = 90000,
  }) => SupportUnitPriceChangeLog(
    id: 'log-1',
    action: action,
    itemName: itemName,
    summary: summary,
    userName: userName,
    createdAt: DateTime.utc(2026, 9, 1, 5, 30),
    oldName: itemName,
    newName: itemName,
    oldPrice: oldPrice,
    newPrice: newPrice,
  );

  test('빈 검색은 모두 통과', () {
    expect(supportUnitPriceMatches(item(), ''), isTrue);
    expect(supportUnitPriceMatches(item(), '  '), isTrue);
  });

  test('품명·규격·비고·금액으로 검색한다', () {
    expect(supportUnitPriceMatches(item(), '모터'), isTrue);
    expect(supportUnitPriceMatches(item(), '800'), isTrue);
    expect(supportUnitPriceMatches(item(), '유상'), isTrue);
    expect(supportUnitPriceMatches(item(), '85000'), isTrue);
    expect(supportUnitPriceMatches(item(), '85,000원'), isTrue);
    expect(supportUnitPriceMatches(item(), '리모컨'), isFalse);
  });

  test('수정한 사람 이름으로도 검색한다', () {
    expect(supportUnitPriceMatches(item(updatedByName: '남현우'), '남현우'), isTrue);
    expect(supportUnitPriceMatches(item(updatedByName: '남현우'), '김경덕'), isFalse);
  });

  test('제품군·영문·인건비로 검색하고 필터한다', () {
    final motor = SupportUnitPriceItem(
      id: '2',
      name: '서보 모터',
      nameEn: 'SERVO MOTOR',
      productLine: 'WMS',
      category: 'MOTOR 모터',
      unit: 'SET',
      price: 700000,
    );
    final labor = SupportUnitPriceItem(
      id: '3',
      name: '모터 교체',
      productLine: 'SPD',
      category: '인건비',
      kind: kSupportUnitPriceKindLabor,
      spec: '슬림형',
      price: 450000,
    );
    expect(supportUnitPriceMatches(motor, 'WMS'), isTrue);
    expect(supportUnitPriceMatches(motor, 'servo'), isTrue);
    expect(supportUnitPriceMatches(labor, '인건비'), isTrue);
    expect(supportUnitPriceInFilter(motor, 'WMS'), isTrue);
    expect(supportUnitPriceInFilter(motor, 'SPD'), isFalse);
    expect(supportUnitPriceInFilter(labor, '인건비'), isTrue);
    expect(
      supportUnitPriceInFilter(
        const SupportUnitPriceItem(
          id: '4',
          name: '토션 스프링 대',
          productLine: 'OHD-산업용',
        ),
        'OHD',
      ),
      isTrue,
    );
    expect(supportUnitPriceSectionOf(motor), 'WMS · MOTOR 모터');
    expect(supportUnitPriceSectionOf(labor), 'SPD · 슬림형');
    expect(supportUnitPriceFamily('OHD-산업용'), 'OHD');
    expect(supportUnitPriceGroupCategory(labor), '슬림형');
    expect(supportUnitPriceRowTitle(labor), '모터 교체');
  });

  test('사진은 image_url을 우선하고 없으면 도해를 쓴다', () {
    const both = SupportUnitPriceItem(
      id: 'p',
      name: '드럼 커버',
      imageUrl: 'assets/as_unit_prices/part_024.jpg',
      diagramUrl: 'assets/as_unit_prices/part_024_d.jpg',
    );
    const onlyDiagram = SupportUnitPriceItem(
      id: 'd',
      name: '가이드 레일',
      diagramUrl: 'assets/as_unit_prices/part_026_d.jpg',
    );
    expect(both.primaryImageUrl, 'assets/as_unit_prices/part_024.jpg');
    expect(both.photoUrls.length, 2);
    expect(onlyDiagram.primaryImageUrl, 'assets/as_unit_prices/part_026_d.jpg');
    expect(const SupportUnitPriceItem(id: 'x', name: '없음').photoUrls, isEmpty);
  });

  test('비고의 타사 금액을 분리한다', () {
    expect(parseSupportUnitPriceCompetitorFromNote('타사 80,000원'), 80000);
    expect(
      parseSupportUnitPriceCompetitorFromNote('신규 · 타사 1,200,000원'),
      1200000,
    );
    expect(stripSupportUnitPriceCompetitorFromNote('신규 · 타사 1,200,000원'), '신규');
    expect(formatSupportUnitPriceCompetitor(80000), '타사 80,000원');
    final fromNote = SupportUnitPriceItem(
      id: 'n',
      name: '윈드바',
      note: '타사 80,000원',
    );
    expect(fromNote.displayCompetitorPrice, 80000);
    expect(fromNote.displayNote, '');
  });

  test('인건비는 제품군 아래 구분·품명을 보여준다', () {
    final a = SupportUnitPriceItem(
      id: '1',
      name: '판넬 교체',
      spec: '타사자동문',
      productLine: 'OHD',
      category: '인건비',
      kind: kSupportUnitPriceKindLabor,
      price: 500000,
    );
    final b = SupportUnitPriceItem(
      id: '2',
      name: '판넬 교체',
      spec: '주택차고문',
      productLine: 'OHD',
      category: '인건비',
      kind: kSupportUnitPriceKindLabor,
      price: 300000,
    );
    expect(supportUnitPriceFamily(a.productLine), 'OHD');
    expect(supportUnitPriceGroupCategory(a), '타사자동문');
    expect(supportUnitPriceRowTitle(a), '판넬 교체');
    expect(supportUnitPriceGroupCategory(b), '주택차고문');
    expect(supportUnitPriceRowTitle(b), '판넬 교체');
    expect(
      supportUnitPriceInsertLine(a),
      'OHD · 타사자동문 · 판넬 교체 · 500,000원',
    );
  });

  test('큰분류·작은분류로 묶고 목록 줄을 만든다', () {
    final a = SupportUnitPriceItem(
      id: '1',
      name: '컨트롤러',
      productLine: 'SPD',
      category: 'CONTROLLER 전자제어장치',
      unit: 'SET',
      price: 900000,
      competitorPrice: 1600000,
    );
    final b = SupportUnitPriceItem(
      id: '2',
      name: '메인보드',
      productLine: 'SPD',
      category: 'CONTROLLER 전자제어장치',
      unit: 'SET',
      price: 900000,
    );
    final c = SupportUnitPriceItem(
      id: '3',
      name: '서보 모터',
      productLine: 'WMS',
      category: 'MOTOR 모터',
      unit: 'SET',
      price: 700000,
    );
    final grouped = groupSupportUnitPrices([a, b, c]);
    expect(grouped.length, 2);
    expect(grouped.first.productLine, 'SPD');
    expect(grouped.first.category, 'CONTROLLER 전자제어장치');
    expect(grouped.first.items.length, 2);
    expect(grouped.last.productLine, 'WMS');
    expect(
      supportUnitPriceListSubtitle(a),
      '타사 1,600,000원',
    );
    expect(
      supportUnitPriceInsertLine(a),
      'SPD · CONTROLLER 전자제어장치 · 컨트롤러 · SET · 900,000원 · 타사 1,600,000원',
    );
  });

  test('단위는 SET·EA·M으로 고른다', () {
    expect(normalizeSupportUnitPriceUnit('set'), 'SET');
    expect(normalizeSupportUnitPriceUnit('ea'), 'EA');
    expect(normalizeSupportUnitPriceUnit('m'), 'M');
    expect(kSupportUnitPriceUnits, ['SET', 'EA', 'M']);
  });

  test('금액 표시는 천 단위 쉼표를 붙인다', () {
    expect(formatSupportUnitPriceWon(85000), '85,000원');
    expect(formatSupportUnitPriceWon(null), '-');
    expect(formatSupportUnitPriceWon(0), '0원');
  });

  test('추가·수정·삭제 요약을 만든다', () {
    expect(
      describeSupportUnitPriceChange(
        action: 'create',
        newName: '모터',
        newSpec: '800N',
        newPrice: 85000,
      ),
      '모터 · 추가 · 800N · 85,000원',
    );
    expect(
      describeSupportUnitPriceChange(
        action: 'delete',
        oldName: '모터',
        oldSpec: '800N',
        oldPrice: 85000,
      ),
      '모터 · 삭제 · 800N · 85,000원',
    );
    expect(
      describeSupportUnitPriceChange(
        action: 'update',
        oldName: '모터',
        newName: '모터',
        oldPrice: 85000,
        newPrice: 90000,
        oldSpec: '800N',
        newSpec: '1000N',
      ),
      '모터 · 규격 800N → 1000N · 단가 85,000원 → 90,000원 (5,000원 인상)',
    );
  });

  test('단가 차액을 인상·인하로 표시한다', () {
    expect(describeSupportUnitPriceDelta(85000, 90000), '5,000원 인상');
    expect(describeSupportUnitPriceDelta(90000, 85000), '5,000원 인하');
    expect(describeSupportUnitPriceDelta(85000, 85000), '차이 없음');
    expect(describeSupportUnitPriceDelta(null, 85000), '85,000원 인상');
    expect(
      formatSupportUnitPriceFromTo(85000, 90000),
      '85,000원 → 90,000원 (5,000원 인상)',
    );
  });

  test('저장 확인은 얼마에서 얼마로와 차액을 넣는다', () {
    expect(
      describeSupportUnitPriceSaveConfirm(
        name: '모터',
        isNew: false,
        oldPrice: 85000,
        newPrice: 90000,
      ),
      '모터 단가를 85,000원에서 90,000원으로\n5,000원 인상하여 저장할까요?',
    );
    expect(
      describeSupportUnitPriceSaveConfirm(
        name: '모터',
        isNew: false,
        oldPrice: 90000,
        newPrice: 85000,
      ),
      '모터 단가를 90,000원에서 85,000원으로\n5,000원 인하하여 저장할까요?',
    );
    expect(
      describeSupportUnitPriceSaveConfirm(
        name: '모터',
        isNew: true,
        newPrice: 85000,
      ),
      '모터을(를) 85,000원으로 추가할까요?',
    );
  });

  test('이력은 누가·품명·금액·추가/수정/삭제로 검색한다', () {
    expect(supportUnitPriceChangeLogMatches(log(), ''), isTrue);
    expect(supportUnitPriceChangeLogMatches(log(), '김경덕'), isTrue);
    expect(supportUnitPriceChangeLogMatches(log(), '모터'), isTrue);
    expect(supportUnitPriceChangeLogMatches(log(), '90,000원'), isTrue);
    expect(supportUnitPriceChangeLogMatches(log(), '인상'), isTrue);
    expect(supportUnitPriceChangeLogMatches(log(), '수정'), isTrue);
    expect(
      supportUnitPriceChangeLogMatches(
        log(action: 'create', summary: '모터 · 추가'),
        '추가',
      ),
      isTrue,
    );
    expect(supportUnitPriceChangeLogMatches(log(), '리모컨'), isFalse);
  });

  test('이력 목록은 품명과 금액 줄을 나눈다', () {
    expect(supportUnitPriceChangeLogTitle(log()), '모터');
    expect(
      supportUnitPriceChangeLogPriceLine(log()),
      '85,000원 → 90,000원 (5,000원 인상)',
    );
    expect(
      supportUnitPriceChangeLogPriceLine(
        log(action: 'create', oldPrice: null, newPrice: 85000),
      ),
      '추가 · 85,000원',
    );
  });

  test('서버 JSON에서 단가·이력을 읽는다', () {
    final parsed = SupportUnitPriceItem.fromJson({
      'id': 'abc',
      'name': '리모컨',
      'spec': '2버튼',
      'price': 35000.0,
      'note': '유상',
      'updated_by_name': '남현우',
      'created_by_name': '김경덕',
      'updated_at': '2026-09-01T05:30:00+00:00',
      'image_url': 'assets/as_unit_prices/part_024.jpg',
    });
    expect(parsed.price, 35000);
    expect(parsed.updatedByName, '남현우');
    expect(parsed.createdByName, '김경덕');
    expect(parsed.imageUrl, 'assets/as_unit_prices/part_024.jpg');

    final change = SupportUnitPriceChangeLog.fromJson({
      'id': 'l1',
      'item_id': 'abc',
      'action': 'update',
      'item_name': '리모컨',
      'summary': '리모컨 · 단가 30,000원 → 35,000원',
      'old_price': 30000,
      'new_price': 35000,
      'user_name': '남현우',
      'created_at': '2026-09-01T05:30:00+00:00',
    });
    expect(change.action, 'update');
    expect(change.oldPrice, 30000);
    expect(change.newPrice, 35000);
    expect(change.userName, '남현우');
  });
}
