import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// 서울 기준 오늘 날짜 `yyyy-MM-dd` (쿼리 `date` 등).
String todayYmdSeoul() {
  final now = tz.TZDateTime.now(tz.local);
  return DateFormat('yyyy-MM-dd').format(now);
}

/// 어떤 DateTime이 들어와도 서울 기준 `yyyy-MM-dd`로 정규화한다.
String ymdSeoulFromDateTime(DateTime input) {
  // 테스트/순수 함수 경로에서는 timezone 초기화가 안 되어 있을 수 있어
  // tz.local 대신 UTC+9 오프셋으로 고정 계산한다.
  final utc = input.isUtc ? input : input.toUtc();
  final seoul = utc.add(const Duration(hours: 9));
  return DateFormat('yyyy-MM-dd').format(seoul);
}

/// 표시용 — 앱 시작 시 `Asia/Seoul` 로컬이 설정되어 있다고 가정.
String formatSeoulDateTime(DateTime? utcOrNull) {
  if (utcOrNull == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm', 'ko_KR').format(_utcToSeoul(utcOrNull));
}

/// Supabase 등 DB 원문 시각 문자열 → 서울 `DateTime`.
DateTime parseSupabaseTimestampAsSeoul(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Empty timestamp');
  }

  final normalized = trimmed.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) {
    throw FormatException('Invalid timestamp: $raw');
  }

  if (dt.isUtc || _hasExplicitTimezone(trimmed)) {
    return _utcToSeoul(dt.isUtc ? dt : dt.toUtc());
  }

  if (!_hasTimeComponent(trimmed)) {
    final datePart = trimmed.split('T').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
  }

  // 타임존 없는 `yyyy-MM-dd HH:mm:ss` — DB UTC 시각으로 해석
  return _utcToSeoul(
    DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    ),
  );
}

/// `call_date` / `call_time` — DB·웹에 **한국 현지 시각**으로 저장된 값(변환 없음).
DateTime parseSalesCallReceptionWallClock(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw FormatException('Empty reception datetime');
  }

  final normalized = trimmed.replaceFirst(' ', 'T');
  final dt = DateTime.tryParse(normalized);
  if (dt == null) {
    throw FormatException('Invalid reception datetime: $raw');
  }

  if (dt.isUtc || _hasExplicitTimezone(trimmed)) {
    return _utcToSeoul(dt.isUtc ? dt : dt.toUtc());
  }

  if (!_hasTimeComponent(trimmed)) {
    final datePart = trimmed.split('T').first;
    final parts = datePart.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
  }

  return DateTime(
    dt.year,
    dt.month,
    dt.day,
    dt.hour,
    dt.minute,
    dt.second,
    dt.millisecond,
    dt.microsecond,
  );
}

bool _hasExplicitTimezone(String raw) {
  final trimmed = raw.trim();
  return trimmed.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(trimmed);
}

bool _hasTimeComponent(String raw) {
  return RegExp(r'\d{2}:\d{2}').hasMatch(raw);
}

DateTime _utcToSeoul(DateTime utc) {
  final asUtc = utc.isUtc ? utc : utc.toUtc();
  try {
    return tz.TZDateTime.from(asUtc, tz.local);
  } catch (_) {
    return asUtc.add(const Duration(hours: 9));
  }
}

/// 고객전화 접수 시각 — `call_date`/`call_time` 우선, 없으면 `created_at`.
DateTime? resolveSalesCallReceptionSeoul({
  String? callDate,
  String? callTime,
  String? createdAt,
}) {
  final d = callDate?.trim() ?? '';
  final t = callTime?.trim() ?? '';

  if (d.isNotEmpty) {
    if (_hasTimeComponent(d) || t.isNotEmpty) {
      final combined = t.isNotEmpty && !_hasTimeComponent(d) ? '$d $t' : d;
      try {
        return parseSalesCallReceptionWallClock(combined);
      } catch (_) {}
    } else if (createdAt != null && createdAt.trim().isNotEmpty) {
      try {
        return parseSupabaseTimestampAsSeoul(createdAt.trim());
      } catch (_) {}
    } else {
      try {
        return parseSalesCallReceptionWallClock(d);
      } catch (_) {}
    }
  }

  if (createdAt != null && createdAt.trim().isNotEmpty) {
    try {
      return parseSupabaseTimestampAsSeoul(createdAt.trim());
    } catch (_) {}
  }
  return null;
}

String formatSalesCallReceptionDateTime({
  String? callDate,
  String? callTime,
  String? createdAt,
}) {
  final seoul = resolveSalesCallReceptionSeoul(
    callDate: callDate,
    callTime: callTime,
    createdAt: createdAt,
  );
  if (seoul == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm', 'ko_KR').format(seoul);
}

String formatSalesCallReceptionShort({
  String? callDate,
  String? callTime,
  String? createdAt,
}) {
  final seoul = resolveSalesCallReceptionSeoul(
    callDate: callDate,
    callTime: callTime,
    createdAt: createdAt,
  );
  if (seoul == null) return '';
  return '${seoul.month}/${seoul.day} '
      '${seoul.hour}:${seoul.minute.toString().padLeft(2, '0')}';
}

String salesCallReceptionYmdForCall({
  String? callDate,
  String? callTime,
  String? createdAt,
}) {
  final seoul = resolveSalesCallReceptionSeoul(
    callDate: callDate,
    callTime: callTime,
    createdAt: createdAt,
  );
  if (seoul == null) return '';
  return DateFormat('yyyy-MM-dd').format(seoul);
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

/// `yyyy-MM-dd`에 [deltaDays]일을 더한 날짜(달력 기준, 로컬).
String addDaysToYmd(String ymd, int deltaDays) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return ymd;
  final next = DateTime(y, m, d).add(Duration(days: deltaDays));
  return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
}

/// [anyYmd]가 속한 주의 **월요일~일요일**(포함) 구간. `weekday`는 `DateTime` 규약(월=1).
(String mondayYmd, String sundayYmd) seoulWeekRangeContaining(String anyYmd) {
  final parts = anyYmd.split('-');
  if (parts.length != 3) return (anyYmd, anyYmd);
  final y = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 1;
  final d = int.tryParse(parts[2]) ?? 1;
  final day = DateTime(y, m, d);
  final fromMon = day.weekday - DateTime.monday;
  final monday = day.subtract(Duration(days: fromMon));
  final sunday = monday.add(const Duration(days: 6));
  String fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  return (fmt(monday), fmt(sunday));
}

/// 홈 상단 인사 — `오늘은 5월12일(화) 입니다.` (서울 당일 기준).
String formatTodayGreetingSentenceKo() {
  final ymd = todayYmdSeoul();
  final parts = ymd.split('-');
  if (parts.length != 3) return '오늘 날짜를 표시할 수 없습니다.';
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) {
    return '오늘 날짜를 표시할 수 없습니다.';
  }
  final day = DateTime(y, m, d);
  const shortWeekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final wd = shortWeekdays[day.weekday - 1];
  return '오늘은 $m월$d일($wd) 입니다.';
}

/// 홈 흐름 요약용 — `5월 12일 (월)` 형태.
String formatYmdFlowLabelKo(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return ymd;
  final day = DateTime(y, m, d);
  return DateFormat('M월 d일 (E)', 'ko_KR').format(day);
}

/// `4/7 ~ 4/13` 형태(연도 생략).
String formatWeekRangeFlowLabel(String monYmd, String sunYmd) {
  String short(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return ymd;
    final m = int.tryParse(p[1]) ?? 0;
    final d = int.tryParse(p[2]) ?? 0;
    return '$m/$d';
  }

  return '${short(monYmd)} ~ ${short(sunYmd)}';
}

/// 해당 월의 1일 `yyyy-MM-dd`.
String firstDayOfMonthYmd(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null) return ymd;
  return '${y}-${m.toString().padLeft(2, '0')}-01';
}

/// [ymd]가 속한 해의 **1월 1일·12월 31일**(포함, `yyyy-MM-dd`).
(String firstYmd, String lastYmd) seoulYearRangeContaining(String ymd) {
  final y = ymd.length >= 4 ? ymd.substring(0, 4) : '${DateTime.now().year}';
  return ('$y-01-01', '$y-12-31');
}

/// [ymd]가 속한 달의 **첫날·마지막날**(포함, `yyyy-MM-dd`).
(String firstYmd, String lastYmd) seoulMonthRangeContaining(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return (ymd, ymd);
  final y = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 1;
  final first = DateTime(y, m, 1);
  final last = DateTime(y, m + 1, 0);
  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return (fmt(first), fmt(last));
}

/// 달력 기준으로 [delta]개월 이동한 달의 **1일**.
String addCalendarMonthsFirstOfMonth(String ymd, int delta) {
  final first = firstDayOfMonthYmd(ymd);
  final parts = first.split('-');
  var y = int.parse(parts[0]);
  var m = int.parse(parts[1]) + delta;
  while (m > 12) {
    m -= 12;
    y++;
  }
  while (m < 1) {
    m += 12;
    y--;
  }
  return '${y}-${m.toString().padLeft(2, '0')}-01';
}

/// `yyyy-MM-dd` 문자열 비교. 유효하지 않으면 문자열 사전순 비교로 폴백.
int compareYmd(String a, String b) {
  DateTime? parse(String v) {
    final p = v.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  final da = parse(a);
  final db = parse(b);
  if (da == null || db == null) return a.compareTo(b);
  return da.compareTo(db);
}

/// KST `targetYmd`가 [startYmd, endYmd] 포함 구간인지 검사.
bool isYmdWithinInclusiveRange(
  String targetYmd, {
  String? startYmd,
  String? endYmd,
}) {
  if (startYmd != null && startYmd.isNotEmpty) {
    if (compareYmd(targetYmd, startYmd) < 0) return false;
  }
  if (endYmd != null && endYmd.isNotEmpty) {
    if (compareYmd(targetYmd, endYmd) > 0) return false;
  }
  return true;
}

/// `2026년 5월` 형태.
String formatYearMonthLabelKo(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return ymd;
  final day = DateTime(y, m, d);
  return DateFormat('y년 M월', 'ko_KR').format(day);
}
