import 'package:coad_customer_calls/core/utils/support_map_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('같은 좌표면 0km', () {
    expect(
      supportDistanceKm(
        fromLat: 37.5665,
        fromLng: 126.978,
        toLat: 37.5665,
        toLng: 126.978,
      ),
      closeTo(0, 0.001),
    );
    expect(supportDistanceLabel(0.08), '80m');
  });

  test('서울-부산은 약 325km', () {
    final km = supportDistanceKm(
      fromLat: 37.5665,
      fromLng: 126.978,
      toLat: 35.1796,
      toLng: 129.0756,
    );
    expect(km, isNotNull);
    expect(km!, greaterThan(300));
    expect(km, lessThan(360));
    expect(supportDistanceLabel(km), '325km');
  });

  test('좌표 없으면 거리를 계산하지 않는다', () {
    expect(
      supportDistanceKm(fromLat: 37.5, fromLng: 127, toLat: null, toLng: 129),
      isNull,
    );
    expect(supportDistanceLabel(null), '');
  });
}
