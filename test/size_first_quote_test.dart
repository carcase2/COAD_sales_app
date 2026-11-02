import 'package:coad_customer_calls/features/quoter/shutter_lowest_quote.dart';
import 'package:coad_customer_calls/features/quoter/size_first_quote.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter_test/flutter_test.dart';

StandardPriceCell _cell(int width, int height, int price) =>
    StandardPriceCell(widthMm: width, heightMm: height, price: price);

void main() {
  test('모델 이름이 셔터 종류와 같으면 셔터 계산으로 연결한다', () {
    expect(shutterTypeForModelName('이중압출'), ShutterType.doubleExtrusion);
    expect(shutterTypeForModelName('내풍압 단열'), ShutterType.windproofInsulated);
    expect(shutterTypeForModelName('이중압출 셔터'), ShutterType.doubleExtrusion);
    expect(shutterTypeForModelName('PREMIUM'), isNull);
  });

  test('셔터는 같은 사이즈에서 더 싼 업체 금액으로 견적에 들어간다', () {
    final quote = runLowestShutterQuote(
      type: ShutterType.doubleExtrusion,
      widthMm: 3000,
      heightMm: 2500,
      prices: {
        'grid': [
          {
            'category': '방범',
            'model_type': '이중압출',
            'width_mm': 3000,
            'height_mm': 3000,
            'price': 700000,
          },
        ],
        'unit': [
          {'category': '방범', 'model_type': '이중압출', 'unit_price': 81000},
        ],
        'company': [
          {
            'id': 'high',
            'company_name': '비싼업체',
            'unit_price_general': 200000,
            'unit_price_insulated': 200000,
            'is_default': true,
            'sort_order': 1,
          },
          {
            'id': 'low',
            'company_name': '싼업체',
            'unit_price_general': 50000,
            'unit_price_insulated': 50000,
            'is_default': false,
            'sort_order': 2,
          },
        ],
      },
    );
    expect(quote.companyName, '싼업체');
    expect(quote.result.totalAmount, greaterThan(0));
    expect(quote.result.motorModel, isNot('-'));
  });

  test('같은 사이즈는 단가가 낮은 모델이 먼저 나오고 없는 단가는 뒤로 간다', () {
    const categories = [
      StandardUnitPriceCategory(
        id: 'speed',
        name: '스피드도어',
        sortOrder: 0,
        color: '#059669',
      ),
      StandardUnitPriceCategory(
        id: 'shutter',
        name: '셔터',
        sortOrder: 1,
        color: '#2563eb',
      ),
    ];
    const models = [
      StandardUnitPriceModel(
        id: 'premium',
        categoryId: 'speed',
        name: 'PREMIUM',
        sortOrder: 0,
        color: '#059669',
      ),
      StandardUnitPriceModel(
        id: 'standard',
        categoryId: 'speed',
        name: 'STANDARD',
        sortOrder: 1,
        color: '#d97706',
      ),
      StandardUnitPriceModel(
        id: 'wind',
        categoryId: 'shutter',
        name: '내풍압',
        sortOrder: 0,
        color: '#2563eb',
      ),
    ];
    final offers = sizeFirstOffers(
      categories: categories,
      models: models,
      cellsByModel: {
        'premium': [_cell(3000, 3000, 2000000)],
        'standard': [_cell(3000, 3000, 1200000)],
        'wind': const [],
      },
      widthMm: 3000,
      heightMm: 3000,
    );

    expect(offers.map((offer) => offer.modelName), [
      'STANDARD',
      'PREMIUM',
      '내풍압',
    ]);
    expect(offers.first.quote.price, 1200000);
    expect(offers.last.quote.price, isNull);
    expect(offers.last.isShutter, isTrue);
    expect(offers.last.shutterType, ShutterType.windproof);

    final speedOnly = sizeFirstOffers(
      categories: categories,
      models: models,
      cellsByModel: {
        'premium': [_cell(3000, 3000, 2000000)],
        'standard': [_cell(3000, 3000, 1200000)],
      },
      widthMm: 3000,
      heightMm: 3000,
      categoryId: 'speed',
    );
    expect(speedOnly.map((offer) => offer.modelName), ['STANDARD', 'PREMIUM']);

    final withShutters = [
      ...speedOnly,
      ...shutterSizeOffers(existing: speedOnly, widthMm: 3000, heightMm: 3000),
    ];
    expect(
      withShutters.where((offer) => offer.isShutter).map((o) => o.modelName),
      ['이중압출', '이중압출단열', '내풍압', '내풍압단열', '철제방화', '스크린방화'],
    );
    expect(
      shutterSizeOffers(
        existing: offers,
        widthMm: 3000,
        heightMm: 3000,
      ).map((offer) => offer.modelName),
      ['이중압출', '이중압출단열', '내풍압단열', '철제방화', '스크린방화'],
    );
    expect(
      sizeFirstOffers(
        categories: categories,
        models: models,
        cellsByModel: const {},
        widthMm: 0,
        heightMm: 3000,
      ),
      isEmpty,
    );
  });
}
