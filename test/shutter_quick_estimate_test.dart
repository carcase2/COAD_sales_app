import 'package:coad_customer_calls/features/quoter/shutter_quick_estimate.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final prices = <String, List<Map<String, dynamic>>>{
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
        'id': 'cheap',
        'company_name': '싼업체',
        'unit_price_general': 60000,
        'unit_price_insulated': 120000,
        'sort_order': 1,
      },
      {
        'id': 'dear',
        'company_name': '비싼업체',
        'unit_price_general': 100000,
        'unit_price_insulated': 160000,
        'sort_order': 2,
      },
    ],
  };

  test('업체를 안 고르면 최저가 업체로 계산한다', () {
    final e = shutterQuickEstimate(
      prices: prices,
      type: ShutterType.doubleExtrusion,
      widthMm: 3000,
      heightMm: 2500,
    );
    expect(e.companyId, 'cheap');
    expect(e.companyName, '싼업체');
    // 기준(비와이메탈) + 등록 업체 2곳
    expect(e.comparisons.map((r) => r.company.id), [
      kShutterBaseCompanyId,
      'cheap',
      'dear',
    ]);
    final cheapest = e.comparisons
        .map((r) => r.totalAmount)
        .reduce((a, b) => a < b ? a : b);
    expect(e.total, cheapest);
  });

  test('고른 업체로 계산하고, 비교표 차이는 그 업체 기준', () {
    final e = shutterQuickEstimate(
      prices: prices,
      type: ShutterType.doubleExtrusion,
      widthMm: 3000,
      heightMm: 2500,
      companyId: 'dear',
    );
    expect(e.companyId, 'dear');
    final dear = e.comparisons.firstWhere((r) => r.company.id == 'dear');
    expect(dear.deltaFromSelected, 0);
    expect(e.total, dear.totalAmount);
    final cheap = e.comparisons.firstWhere((r) => r.company.id == 'cheap');
    expect(cheap.deltaFromSelected, lessThan(0));
  });

  test('비용을 바꾸면 그만큼 합계가 바뀐다', () {
    final base = shutterQuickEstimate(
      prices: prices,
      type: ShutterType.doubleExtrusion,
      widthMm: 3000,
      heightMm: 2500,
      companyId: 'cheap',
    );
    final more = shutterQuickEstimate(
      prices: prices,
      type: ShutterType.doubleExtrusion,
      widthMm: 3000,
      heightMm: 2500,
      companyId: 'cheap',
      costs: const ShutterQuickCosts().copyWith(install: 900000),
    );
    expect(more.total - base.total, 100000);
    expect(const ShutterQuickCosts().isDefault, isTrue);
    expect(const ShutterQuickCosts(install: 900000).isDefault, isFalse);
  });

  test('방화 셔터는 업체 비교 없이 계산한다', () {
    final e = shutterQuickEstimate(
      prices: {
        ...prices,
        'grid': [
          {
            'category': '철제방화',
            'model_type': '',
            'width_mm': 3000,
            'height_mm': 3000,
            'price': 2100000,
          },
        ],
      },
      type: ShutterType.fireSteel,
      widthMm: 3000,
      heightMm: 3000,
    );
    expect(e.comparisons, isEmpty);
    expect(e.companyId, isNull);
    expect(e.total, greaterThan(0));
  });
}
