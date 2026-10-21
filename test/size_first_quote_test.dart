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
