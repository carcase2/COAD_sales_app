/// 표준단가 격자: 폭/높이 2000~8000mm, 1000mm 단위.
const standardSizeSteps = [2000, 3000, 4000, 5000, 6000, 7000, 8000];

const standardColorPalette = [
  '#059669',
  '#d97706',
  '#2563eb',
  '#7c3aed',
  '#db2777',
  '#0d9488',
  '#c2410c',
  '#44403c',
  '#0284c7',
  '#78716c',
];

String nextStandardColor(Iterable<String> used) {
  final taken = used.map((c) => c.toLowerCase()).toSet();
  return standardColorPalette.firstWhere(
    (c) => !taken.contains(c.toLowerCase()),
    orElse: () => '#334155',
  );
}

String normalizeHexColor(String? value, [String fallback = '#334155']) {
  final raw = (value ?? '').trim();
  final hex = raw.startsWith('#') ? raw : '#$raw';
  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return hex.toLowerCase();
  return fallback;
}
const standardSizeMin = 2000;
const standardSizeMax = 8000;
const standardSizeStep = 1000;

enum StandardAdjustType { percent, amount, manual }

class StandardPriceCell {
  const StandardPriceCell({
    required this.widthMm,
    required this.heightMm,
    required this.price,
    this.id,
    this.available = true,
  });

  final String? id;
  final int widthMm;
  final int heightMm;
  final int price;
  final bool available;
}

class StandardPriceInference {
  const StandardPriceInference({
    required this.inputWidth,
    required this.inputHeight,
    required this.bucketWidth,
    required this.bucketHeight,
    required this.isExactBucket,
    required this.match,
    required this.nearby,
  });

  final int inputWidth;
  final int inputHeight;
  final int bucketWidth;
  final int bucketHeight;
  final bool isExactBucket;
  final StandardPriceCell? match;
  final List<StandardPriceCell> nearby;
}

int toStandardSizeBucket(num val) {
  if (val <= standardSizeMin) return standardSizeMin;
  if (val >= standardSizeMax) return standardSizeMax;
  return (val / standardSizeStep).round() * standardSizeStep;
}

List<int> uniqueSortedSizes(Iterable<int> values) {
  final set = values.where((v) => v > 0).toSet().toList()..sort();
  return set;
}

({List<int> widths, List<int> heights}) gridAxesFromCells(
  Iterable<StandardPriceCell> cells,
) {
  final widths = uniqueSortedSizes(cells.map((c) => c.widthMm));
  final heights = uniqueSortedSizes(cells.map((c) => c.heightMm));
  return (
    widths: widths.isEmpty ? List<int>.from(standardSizeSteps) : widths,
    heights: heights.isEmpty ? List<int>.from(standardSizeSteps) : heights,
  );
}

int nearestSize(num val, List<int> axes) {
  if (axes.isEmpty) return toStandardSizeBucket(val);
  return axes.reduce(
    (best, axis) => (axis - val).abs() < (best - val).abs() ? axis : best,
  );
}

int applyPriceAdjustment({
  required int oldPrice,
  required StandardAdjustType type,
  required num value,
}) {
  if (type == StandardAdjustType.percent) {
    if (oldPrice <= 0) return oldPrice;
    final next = (oldPrice * (1 + value / 100)).round();
    return next < 0 ? 0 : next;
  }
  if (type == StandardAdjustType.amount) {
    final next = (oldPrice + value).round();
    return next < 0 ? 0 : next;
  }
  return oldPrice;
}

StandardPriceInference inferStandardPrice({
  required List<StandardPriceCell> cells,
  required int widthMm,
  required int heightMm,
}) {
  final axes = gridAxesFromCells(cells);
  final bucketWidth = nearestSize(widthMm, axes.widths);
  final bucketHeight = nearestSize(heightMm, axes.heights);
  StandardPriceCell? match;
  for (final cell in cells) {
    if (cell.widthMm == bucketWidth && cell.heightMm == bucketHeight) {
      match = cell;
      break;
    }
  }

  final nearby = cells
      .where(
        (cell) =>
            !(cell.widthMm == bucketWidth && cell.heightMm == bucketHeight),
      )
      .map(
        (cell) => (
          cell: cell,
          dist:
              (cell.widthMm - bucketWidth).abs() +
              (cell.heightMm - bucketHeight).abs(),
        ),
      )
      .toList()
    ..sort((a, b) {
      final d = a.dist.compareTo(b.dist);
      if (d != 0) return d;
      final w = a.cell.widthMm.compareTo(b.cell.widthMm);
      if (w != 0) return w;
      return a.cell.heightMm.compareTo(b.cell.heightMm);
    });

  return StandardPriceInference(
    inputWidth: widthMm,
    inputHeight: heightMm,
    bucketWidth: bucketWidth,
    bucketHeight: bucketHeight,
    isExactBucket: widthMm == bucketWidth && heightMm == bucketHeight,
    match: match,
    nearby: nearby.take(8).map((row) => row.cell).toList(growable: false),
  );
}

String standardAdjustTypeLabel(String type) {
  switch (type) {
    case 'percent':
      return '% 조정';
    case 'amount':
      return '금액 조정';
    default:
      return '개별 수정';
  }
}

String _plainWon(int n) {
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String describeStandardAdjustment({
  required String type,
  required num value,
  required int cells,
  String? id,
  List<({String? adjustmentId, int? widthMm, int? heightMm, int oldPrice, int newPrice})>
      logs = const [],
}) {
  if (type == 'percent') {
    final n = value.toDouble();
    return '전체 ${n.abs() == n.abs().roundToDouble() ? n.abs().round() : n.abs()}% ${n < 0 ? '인하' : '인상'}';
  }
  if (type == 'amount') {
    final n = value.round();
    return '전체 ${_plainWon(n)}원 ${n < 0 ? '인하' : '인상'}';
  }
  final mine = id == null
      ? logs
      : logs.where((log) => log.adjustmentId == id).toList();
  if (mine.length == 1) {
    final delta = mine.first.newPrice - mine.first.oldPrice;
    return '${mine.first.widthMm}×${mine.first.heightMm} ${_plainWon(delta)}원 ${delta < 0 ? '인하' : '인상'}';
  }
  if (mine.length > 1) return '개별 ${mine.length}칸 수정';
  return '개별 수정';
}

class PriceChangePeriodStat {
  const PriceChangePeriodStat({
    required this.key,
    required this.label,
    required this.changeCount,
    required this.raiseCount,
    required this.cutCount,
    required this.netWon,
    required this.raiseWon,
    required this.cutWon,
    required this.avgPct,
  });

  final String key;
  final String label;
  final int changeCount;
  final int raiseCount;
  final int cutCount;
  final int netWon;
  final int raiseWon;
  final int cutWon;
  final double avgPct;
}

class PriceChangeStats {
  const PriceChangeStats({
    required this.total,
    required this.raiseCount,
    required this.cutCount,
    required this.netWon,
    required this.lastAt,
    required this.yearly,
    required this.quarterly,
  });

  final int total;
  final int raiseCount;
  final int cutCount;
  final int netWon;
  final DateTime? lastAt;
  final List<PriceChangePeriodStat> yearly;
  final List<PriceChangePeriodStat> quarterly;
}

({int year, int quarter}) seoulYearQuarter(DateTime dt) {
  final local = dt.toLocal();
  return (year: local.year, quarter: ((local.month - 1) ~/ 3) + 1);
}

PriceChangeStats buildPriceChangeStats(
  Iterable<({int oldPrice, int newPrice, DateTime createdAt})> logs,
) {
  final yearly = <String, PriceChangePeriodStat>{};
  final quarterly = <String, PriceChangePeriodStat>{};
  var raiseCount = 0;
  var cutCount = 0;
  var netWon = 0;
  DateTime? lastAt;

  PriceChangePeriodStat empty(String key, String label) => PriceChangePeriodStat(
        key: key,
        label: label,
        changeCount: 0,
        raiseCount: 0,
        cutCount: 0,
        netWon: 0,
        raiseWon: 0,
        cutWon: 0,
        avgPct: 0,
      );

  PriceChangePeriodStat apply(PriceChangePeriodStat p, int oldP, int newP) {
    final delta = newP - oldP;
    final nextCount = p.changeCount + 1;
    var avg = p.avgPct;
    if (oldP > 0) {
      final pct = ((newP - oldP) / oldP) * 100;
      avg = (p.avgPct * p.changeCount + pct) / nextCount;
    }
    return PriceChangePeriodStat(
      key: p.key,
      label: p.label,
      changeCount: nextCount,
      raiseCount: p.raiseCount + (delta > 0 ? 1 : 0),
      cutCount: p.cutCount + (delta < 0 ? 1 : 0),
      netWon: p.netWon + delta,
      raiseWon: p.raiseWon + (delta > 0 ? delta : 0),
      cutWon: p.cutWon + (delta < 0 ? delta : 0),
      avgPct: avg,
    );
  }

  for (final log in logs) {
    final delta = log.newPrice - log.oldPrice;
    netWon += delta;
    if (delta > 0) raiseCount += 1;
    if (delta < 0) cutCount += 1;
    if (lastAt == null || log.createdAt.isAfter(lastAt)) lastAt = log.createdAt;
    final yq = seoulYearQuarter(log.createdAt);
    final yKey = '${yq.year}';
    final qKey = '${yq.year}-Q${yq.quarter}';
    yearly[yKey] = apply(
      yearly[yKey] ?? empty(yKey, '${yq.year}년'),
      log.oldPrice,
      log.newPrice,
    );
    quarterly[qKey] = apply(
      quarterly[qKey] ?? empty(qKey, '${yq.year}년 ${yq.quarter}분기'),
      log.oldPrice,
      log.newPrice,
    );
  }

  final yearList = yearly.values.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  final quarterList = quarterly.values.toList()
    ..sort((a, b) => b.key.compareTo(a.key));

  return PriceChangeStats(
    total: logs.length,
    raiseCount: raiseCount,
    cutCount: cutCount,
    netWon: netWon,
    lastAt: lastAt,
    yearly: yearList,
    quarterly: quarterList,
  );
}

String _csvCell(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String buildStandardPriceGridCsv({
  required String title,
  required List<int> widths,
  required List<int> heights,
  required String Function(int width, int height) cellText,
}) {
  final buf = StringBuffer()
    ..writeln(_csvCell(title))
    ..writeln(['높이\\폭', ...widths.map((w) => '$w')].map(_csvCell).join(','));
  for (final h in heights) {
    buf.writeln(
      ['$h', ...widths.map((w) => cellText(w, h))].map(_csvCell).join(','),
    );
  }
  buf.writeln();
  return buf.toString();
}
