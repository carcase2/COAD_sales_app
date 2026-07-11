import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/features/quoter/quoter_company_models.dart';
import 'package:coad_customer_calls/features/quoter/quoter_formatters.dart';
import 'package:coad_customer_calls/features/quoter/quoter_providers.dart';
import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ThousandsFormatter', () {
    const formatter = ThousandsFormatter();

    TextEditingValue apply(
      String oldText,
      String newText, {
      int? newSelection,
    }) {
      return formatter.formatEditUpdate(
        TextEditingValue(
          text: oldText,
          selection: TextSelection.collapsed(offset: oldText.length),
        ),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: newSelection ?? newText.length,
          ),
        ),
      );
    }

    test('빈 입력 유지', () {
      expect(apply('1', '').text, isEmpty);
    });

    test('천 단위 콤마', () {
      expect(apply('', '1000').text, '1,000');
      expect(apply('1,000', '10000').text, '10,000');
    });

    test('숫자가 아니면 이전 값 유지', () {
      expect(apply('1,000', '1,000a').text, '1,000');
    });

    test('중간 편집 시 커서 자릿수 유지', () {
      // "1,234" 중 "2" 앞(인덱스 2, 숫자 1자리 뒤)에 0 삽입 → "10,234", 커서는 "0" 뒤
      final result = apply(
        '1,234',
        '10,234',
        newSelection: 2, // after inserted '0' in raw "10234" view... actually newText is "10,234"
      );
      expect(result.text, '10,234');
      // digits before caret in "10,234" at offset 2 is "1" only → caret after first digit
      // Wait: newText "10,234", selection 2 → substring "10" → 2 digits → caret after "10" in "10,234" = 2
      expect(result.selection.baseOffset, 2);
    });
  });

  group('QuoterTypeStyle', () {
    test('모든 타입에 라벨·아이콘·색 존재', () {
      for (final type in ShutterType.values) {
        expect(QuoterTypeStyle.label(type), isNotEmpty);
        expect(QuoterTypeStyle.icon(type), isNotNull);
        expect(QuoterTypeStyle.color(type), isNotNull);
      }
    });

    test('이중압출 라벨', () {
      expect(QuoterTypeStyle.label(ShutterType.doubleExtrusion), '이중압출');
      expect(QuoterTypeStyle.label(ShutterType.fireScreen), '스크린방화');
    });
  });

  group('quoterStepAccent', () {
    test('1–4 단계 악센트', () {
      expect(quoterStepAccent(1), kQuoterStepAccents[0]);
      expect(quoterStepAccent(4), kQuoterStepAccents[3]);
    });
  });

  group('ShutterCompanyUnitPrice', () {
    test('fromJson 파싱', () {
      final row = ShutterCompanyUnitPrice.fromJson(
        {
          'id': 'c1',
          'company_name': 'A사',
          'unit_price_general': 90000,
          'unit_price_insulated': '150000',
          'is_default': true,
          'sort_order': 1,
        },
        fallbackId: 'fallback',
      );
      expect(row.id, 'c1');
      expect(row.companyName, 'A사');
      expect(row.unitPriceGeneral, 90000);
      expect(row.unitPriceInsulated, 150000);
      expect(row.isDefault, isTrue);
    });

    test('빈 id/이름 폴백', () {
      final row = ShutterCompanyUnitPrice.fromJson(
        {
          'company_name': '  ',
          'unit_price_general': 0,
          'unit_price_insulated': 0,
        },
        fallbackId: 'fb',
      );
      expect(row.id, 'fb');
      expect(row.companyName, '이름 미등록');
    });

    test('CompanyComparisonRow.copyWith', () {
      const company = ShutterCompanyUnitPrice(
        id: '1',
        companyName: 'A',
        unitPriceGeneral: 1,
        unitPriceInsulated: 2,
        isDefault: false,
        sortOrder: 0,
      );
      const row = CompanyComparisonRow(
        company: company,
        totalAmount: 100,
        slatAmount: 50,
      );
      expect(row.copyWith(deltaFromSelected: -10).deltaFromSelected, -10);
      expect(row.copyWith(deltaFromSelected: -10).totalAmount, 100);
    });
  });

  group('parseCachedPriceList / isShutterPriceCacheFresh', () {
    test('정상 JSON 파싱', () {
      final list = parseCachedPriceList('[{"a":1},{"b":2}]');
      expect(list, isNotNull);
      expect(list!.length, 2);
      expect(list[0]['a'], 1);
    });

    test('손상 JSON → null', () {
      expect(parseCachedPriceList('{not-json'), isNull);
      expect(parseCachedPriceList('null'), isNull);
      expect(parseCachedPriceList(''), isNull);
      expect(parseCachedPriceList(null), isNull);
    });

    test('TTL 신선도', () {
      final now = DateTime(2026, 7, 12, 12);
      expect(
        isShutterPriceCacheFresh(
          cachedAtRaw: now.subtract(const Duration(hours: 1)).toIso8601String(),
          ttl: const Duration(hours: 24),
          now: now,
        ),
        isTrue,
      );
      expect(
        isShutterPriceCacheFresh(
          cachedAtRaw: now.subtract(const Duration(hours: 25)).toIso8601String(),
          ttl: const Duration(hours: 24),
          now: now,
        ),
        isFalse,
      );
      expect(
        isShutterPriceCacheFresh(
          cachedAtRaw: 'bad',
          ttl: const Duration(hours: 24),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('loadShutterPrices', () {
    late SharedPreferences prefs;
    final grid = [
      {'w': 1000, 'h': 2000, 'price': 100},
    ];
    final unit = [
      {'type': 'g', 'price': 90000},
    ];
    final company = [
      {'id': 'c1', 'company_name': 'A'},
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('캐시 미스 시 네트워크 fetch 후 디스크 저장', () async {
      var gridCalls = 0;
      var unitCalls = 0;
      var companyCalls = 0;
      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async {
          gridCalls++;
          return grid;
        },
        fetchUnit: () async {
          unitCalls++;
          return unit;
        },
        fetchCompany: () async {
          companyCalls++;
          return company;
        },
        now: DateTime(2026, 7, 12),
      );
      expect(result['grid'], grid);
      expect(result['unit'], unit);
      expect(result['company'], company);
      expect(gridCalls, 1);
      expect(unitCalls, 1);
      expect(companyCalls, 1);
      expect(prefs.getString(StorageKeys.shutterPriceGridCache), isNotNull);
      expect(prefs.getString(StorageKeys.shutterPriceCompanyCache), isNotNull);
    });

    test('신선한 캐시 히트 시 네트워크 미호출', () async {
      await writeShutterPriceCache(
        prefs,
        grid: grid,
        unit: unit,
        company: company,
        now: DateTime(2026, 7, 12, 10),
      );
      var network = 0;
      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async {
          network++;
          return grid;
        },
        fetchUnit: () async {
          network++;
          return unit;
        },
        fetchCompany: () async {
          network++;
          return company;
        },
        now: DateTime(2026, 7, 12, 12),
      );
      expect(network, 0);
      expect(result['grid']!.first['price'], 100);
      expect(result['company']!.first['id'], 'c1');
    });

    test('forceRefresh는 1회만 네트워크 (캐시 있어도)', () async {
      await writeShutterPriceCache(
        prefs,
        grid: grid,
        unit: unit,
        company: company,
        now: DateTime(2026, 7, 12, 10),
      );
      final fresh = [
        {'w': 1, 'price': 999},
      ];
      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async => fresh,
        fetchUnit: () async => unit,
        fetchCompany: () async => company,
        forceRefresh: true,
        now: DateTime(2026, 7, 12, 12),
      );
      expect(result['grid']!.first['price'], 999);

      // 이후 force 없이 다시 로드하면 방금 쓴 캐시 사용
      var gridCalls = 0;
      final again = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async {
          gridCalls++;
          return grid;
        },
        fetchUnit: () async => unit,
        fetchCompany: () async => company,
        now: DateTime(2026, 7, 12, 12),
      );
      expect(gridCalls, 0);
      expect(again['grid']!.first['price'], 999);
    });

    test('회사 fetch 실패해도 그리드/단가로 성공', () async {
      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async => grid,
        fetchUnit: () async => unit,
        fetchCompany: () async => throw Exception('company down'),
        now: DateTime(2026, 7, 12),
      );
      expect(result['grid'], grid);
      expect(result['unit'], unit);
      expect(result['company'], isEmpty);
    });

    test('회사 fetch 실패 시 이전 회사 캐시 폴백', () async {
      await writeShutterPriceCache(
        prefs,
        grid: grid,
        unit: unit,
        company: company,
        now: DateTime(2026, 7, 1), // stale → force network for grid/unit
      );
      // clear only grid/unit freshness by setting old cachedAt; company still in prefs
      await prefs.setString(
        StorageKeys.shutterPriceCachedAt,
        DateTime(2026, 7, 1).toIso8601String(),
      );

      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async => grid,
        fetchUnit: () async => unit,
        fetchCompany: () async => throw Exception('company down'),
        now: DateTime(2026, 7, 12),
      );
      expect(result['company']!.first['id'], 'c1');
    });

    test('손상된 캐시는 무시하고 네트워크', () async {
      await prefs.setString(StorageKeys.shutterPriceGridCache, '{bad');
      await prefs.setString(StorageKeys.shutterPriceUnitCache, '[]');
      await prefs.setString(
        StorageKeys.shutterPriceCachedAt,
        DateTime(2026, 7, 12).toIso8601String(),
      );
      var gridCalls = 0;
      final result = await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async {
          gridCalls++;
          return grid;
        },
        fetchUnit: () async => unit,
        fetchCompany: () async => company,
        now: DateTime(2026, 7, 12),
      );
      expect(gridCalls, 1);
      expect(result['grid'], grid);
    });

    test('clearShutterPriceCache 후 네트워크 재호출', () async {
      await writeShutterPriceCache(
        prefs,
        grid: grid,
        unit: unit,
        company: company,
        now: DateTime(2026, 7, 12),
      );
      await clearShutterPriceCache(prefs);
      var calls = 0;
      await loadShutterPrices(
        prefs: prefs,
        fetchGrid: () async {
          calls++;
          return grid;
        },
        fetchUnit: () async => unit,
        fetchCompany: () async => company,
        now: DateTime(2026, 7, 12),
      );
      expect(calls, 1);
    });
  });
}
