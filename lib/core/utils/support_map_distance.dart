import 'dart:math' as math;

/// 두 좌표 사이 거리(km). 위·경도가 없으면 null.
double? supportDistanceKm({
  required double? fromLat,
  required double? fromLng,
  required double? toLat,
  required double? toLng,
}) {
  if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
    return null;
  }
  const earthKm = 6371.0;
  final p1 = fromLat * math.pi / 180;
  final p2 = toLat * math.pi / 180;
  final dLat = (toLat - fromLat) * math.pi / 180;
  final dLng = (toLng - fromLng) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthKm * c;
}

String supportDistanceLabel(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000).round()}m';
  if (km < 10) return '${km.toStringAsFixed(1)}km';
  return '${km.round()}km';
}
