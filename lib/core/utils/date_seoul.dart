import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// 서울 기준 오늘 날짜 `yyyy-MM-dd` (쿼리 `date` 등).
String todayYmdSeoul() {
  final now = tz.TZDateTime.now(tz.local);
  return DateFormat('yyyy-MM-dd').format(now);
}

/// 표시용 — 앱 시작 시 `Asia/Seoul` 로컬이 설정되어 있다고 가정.
String formatSeoulDateTime(DateTime? utcOrNull) {
  if (utcOrNull == null) return '—';
  final utc = utcOrNull.isUtc ? utcOrNull : utcOrNull.toUtc();
  final local = tz.TZDateTime.from(utc, tz.local);
  return DateFormat('yyyy-MM-dd HH:mm', 'ko_KR').format(local);
}

String formatSeoulDate(String? ymd) {
  if (ymd == null || ymd.isEmpty) return '—';
  try {
    final d = DateTime.parse(ymd);
    final utc = d.isUtc ? d : d.toUtc();
    final local = tz.TZDateTime.from(utc, tz.local);
    return DateFormat('yyyy-MM-dd', 'ko_KR').format(local);
  } catch (_) {
    return ymd;
  }
}
