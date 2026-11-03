import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 빠른 규격 버튼 — 최근 180일 견적에서 많이 쓴 값 (500mm 단위, 작은 순).
/// 폭은 3,000~5,000, 높이는 3,000~4,000이 가장 많고 8,000mm 폭도 잦다.
const kQuoterQuickWidths = [2500, 3000, 3500, 4000, 4500, 5000, 6000, 7000, 8000];
const kQuoterQuickHeights = [2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000];

/// 최근 입력 규격 — 버튼 앞에 둔다. 축마다 최대 개수.
const kQuoterRecentPerAxis = 3;
const _recentKey = 'quoter_recent_sizes_v1';
const _recentKeep = 12;

/// 「3000x2500」「3,000 × 2,500」「W3000 H2500」「3.0m*2.5m」 → (폭, 높이) mm.
/// 숫자가 둘 이상 없거나 규격으로 볼 수 없으면 null.
({int width, int height})? parseShutterSizePair(String raw) {
  // 전화번호를 복사해 둔 채 누르면 규격으로 잘못 채우지 않게.
  if (RegExp(r'\d{2,4}-\d{3,4}-\d{4}').hasMatch(raw)) return null;
  final text = raw.replaceAll(RegExp(r'(?<=\d),(?=\d{3})'), '');
  final numbers = RegExp(r'\d+(?:\.\d+)?')
      .allMatches(text)
      .map((m) => double.parse(m.group(0)!))
      .map((v) => v <= 30 ? (v * 1000).round() : v.round()) // 30 이하는 m로 본다
      .where((mm) => mm >= 300 && mm <= 30000)
      .toList();
  if (numbers.length < 2) return null;
  return (width: numbers[0], height: numbers[1]);
}

/// 최근 값(최근 순, 중복 없음)을 앞에, 나머지는 기본값 순서로.
/// [recent]에 있는 값은 기본값에서 빼서 버튼이 두 번 나오지 않게 한다.
List<({int mm, bool recent})> quoterQuickSizes({
  required List<int> defaults,
  required List<int> recent,
}) {
  final seen = <int>{};
  return [
    for (final mm in recent)
      if (mm > 0 && seen.length < kQuoterRecentPerAxis && seen.add(mm))
        (mm: mm, recent: true),
    for (final mm in defaults)
      if (seen.add(mm)) (mm: mm, recent: false),
  ];
}

/// 견적 산출에 쓴 규격을 최근 목록 앞에 넣는다.
Future<void> rememberQuoterSize(int widthMm, int heightMm) async {
  if (widthMm <= 0 || heightMm <= 0) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final entry = '${widthMm}x$heightMm';
    final list = prefs.getStringList(_recentKey) ?? const [];
    await prefs.setStringList(_recentKey, [
      entry,
      ...list.where((e) => e != entry),
    ].take(_recentKeep).toList());
  } catch (_) {}
}

/// 최근 규격 — 폭 목록과 높이 목록 (각각 최근 순).
Future<({List<int> widths, List<int> heights})> loadQuoterRecentSizes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pairs = (prefs.getStringList(_recentKey) ?? const [])
        .map(parseShutterSizePair)
        .whereType<({int width, int height})>()
        .toList();
    return (
      widths: [for (final p in pairs) p.width],
      heights: [for (final p in pairs) p.height],
    );
  } catch (_) {
    return (widths: const <int>[], heights: const <int>[]);
  }
}

/// 단가표(2,000~8,000mm) 밖이면 어느 축을 몇 mm로 계산했는지 — 안이면 null.
/// 예: 「폭 9,000 → 8,000mm 기준 금액 · 별도 확인」
String? quoterTableClampNote(int widthMm, int heightMm) {
  String fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  String? axis(String name, int v) {
    if (v <= 0) return null;
    if (v > ShutterCalculator.maxBucket) {
      return '$name ${fmt(v)} → ${fmt(ShutterCalculator.maxBucket)}';
    }
    if (v < ShutterCalculator.minBucket) {
      return '$name ${fmt(v)} → ${fmt(ShutterCalculator.minBucket)}';
    }
    return null;
  }

  final parts = [
    axis('폭', widthMm),
    axis('높이', heightMm),
  ].whereType<String>().toList();
  if (parts.isEmpty) return null;
  return '${parts.join(' · ')}mm 기준 금액 · 별도 확인';
}
