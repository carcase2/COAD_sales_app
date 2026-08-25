import 'dart:math' as math;

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

/// 현장에서 자주 누르는 폭/높이. 차고문은 높이만 4단·5단.
const standardQuickWidths = [2000, 2500, 3000, 3500, 4000, 4500, 5000, 6000];
const standardQuickHeights = [2000, 2500, 3000, 3500, 4000, 4500, 5000, 6000];
const garageQuickHeights = [2150, 2700];

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

class StandardHighlightCell {
  const StandardHighlightCell({required this.widthMm, required this.heightMm});

  final int widthMm;
  final int heightMm;

  String get key => '${widthMm}_$heightMm';
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
    required this.lowerWidth,
    required this.upperWidth,
    required this.lowerHeight,
    required this.upperHeight,
    required this.estimatedPrice,
    required this.isEstimated,
    required this.outOfRange,
    required this.rangeMinWidth,
    required this.rangeMaxWidth,
    required this.rangeMinHeight,
    required this.rangeMaxHeight,
    required this.highlightCells,
  });

  final int inputWidth;
  final int inputHeight;
  final int bucketWidth;
  final int bucketHeight;
  final bool isExactBucket;
  final StandardPriceCell? match;
  final List<StandardPriceCell> nearby;
  final int lowerWidth;
  final int upperWidth;
  final int lowerHeight;
  final int upperHeight;
  final int? estimatedPrice;
  final bool isEstimated;
  final bool outOfRange;
  final int rangeMinWidth;
  final int rangeMaxWidth;
  final int rangeMinHeight;
  final int rangeMaxHeight;
  final List<StandardHighlightCell> highlightCells;
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

({int lo, int hi}) enclosingSizes(num val, List<int> axes) {
  if (axes.isEmpty) {
    final bucket = toStandardSizeBucket(val);
    return (lo: bucket, hi: bucket);
  }
  if (val <= axes.first) return (lo: axes.first, hi: axes.first);
  for (var i = 0; i < axes.length; i++) {
    if (val == axes[i]) return (lo: axes[i], hi: axes[i]);
    if (i < axes.length - 1 && val > axes[i] && val < axes[i + 1]) {
      return (lo: axes[i], hi: axes[i + 1]);
    }
  }
  return (lo: axes.last, hi: axes.last);
}

bool sizeInAxisRange(num val, List<int> axes) {
  if (axes.isEmpty) return false;
  return val >= axes.first && val <= axes.last;
}

int? ceilingSize(num val, List<int> axes) {
  if (axes.isEmpty) return null;
  for (final axis in axes) {
    if (axis >= val) return axis;
  }
  return null;
}

String heightDanLabel(int mm) {
  if (mm == 2150) return '2150 (4단)';
  if (mm == 2700) return '2700 (5단)';
  return '$mm';
}

int? _usableCellPrice(StandardPriceCell? cell) {
  if (cell == null || cell.available == false) return null;
  if (cell.price <= 0) return null;
  return cell.price;
}

({List<int> widths, List<int> heights}) pricedAxesFromCells(
  Iterable<StandardPriceCell> cells,
) {
  final priced = cells.where((cell) => _usableCellPrice(cell) != null);
  return (
    widths: uniqueSortedSizes(priced.map((c) => c.widthMm)),
    heights: uniqueSortedSizes(priced.map((c) => c.heightMm)),
  );
}

double _lerpPrice(num a, num b, num t) => (a + (b - a) * t).toDouble();

double _tAlong(num val, num lo, num hi) {
  if (hi == lo) return 0;
  return (val - lo) / (hi - lo);
}

List<StandardHighlightCell> _uniqueHighlightCells(
  Iterable<StandardHighlightCell> cells,
) {
  final seen = <String>{};
  final out = <StandardHighlightCell>[];
  for (final cell in cells) {
    if (!seen.add(cell.key)) continue;
    out.add(cell);
  }
  return out;
}

int? _interpolateGridPrice({
  required Map<String, StandardPriceCell> byKey,
  required int widthMm,
  required int heightMm,
  required int wLo,
  required int wHi,
  required int hLo,
  required int hHi,
}) {
  int? get(int w, int h) => _usableCellPrice(byKey['${w}_$h']);
  var p00 = get(wLo, hLo);
  var p10 = get(wHi, hLo);
  var p01 = get(wLo, hHi);
  var p11 = get(wHi, hHi);
  final present = [p00, p10, p01, p11].whereType<int>().length;
  if (present == 0) return null;

  if (present == 3) {
    if (p00 == null && p10 != null && p01 != null && p11 != null) {
      p00 = p10 + p01 - p11;
    } else if (p10 == null && p00 != null && p01 != null && p11 != null) {
      p10 = p00 + p11 - p01;
    } else if (p01 == null && p00 != null && p10 != null && p11 != null) {
      p01 = p00 + p11 - p10;
    } else if (p11 == null && p00 != null && p10 != null && p01 != null) {
      p11 = p10 + p01 - p00;
    }
  }

  final tx = _tAlong(widthMm, wLo, wHi);
  final ty = _tAlong(heightMm, hLo, hHi);

  if (p00 != null && p10 != null && p01 != null && p11 != null) {
    final alongLo = _lerpPrice(p00, p10, tx);
    final alongHi = _lerpPrice(p01, p11, tx);
    final v = _lerpPrice(alongLo, alongHi, ty).round();
    return v < 0 ? 0 : v;
  }

  int lerp1(int a, int b, double t) {
    final v = _lerpPrice(a, b, t).round();
    return v < 0 ? 0 : v;
  }

  if (p00 != null && p10 != null && p01 == null && p11 == null) {
    return lerp1(p00, p10, tx);
  }
  if (p01 != null && p11 != null && p00 == null && p10 == null) {
    return lerp1(p01, p11, tx);
  }
  if (p00 != null && p01 != null && p10 == null && p11 == null) {
    return lerp1(p00, p01, ty);
  }
  if (p10 != null && p11 != null && p00 == null && p01 == null) {
    return lerp1(p10, p11, ty);
  }

  final pts = <({int w, int h, int p})>[
    if (p00 != null) (w: wLo, h: hLo, p: p00),
    if (p10 != null) (w: wHi, h: hLo, p: p10),
    if (p01 != null) (w: wLo, h: hHi, p: p01),
    if (p11 != null) (w: wHi, h: hHi, p: p11),
  ];
  var weightedSum = 0.0;
  var weightSum = 0.0;
  for (final pt in pts) {
    final dist = _hypot(widthMm - pt.w, heightMm - pt.h);
    final weight = 1 / (dist == 0 ? 1e-6 : dist);
    weightedSum += pt.p * weight;
    weightSum += weight;
  }
  if (weightSum <= 0) return null;
  final v = (weightedSum / weightSum).round();
  return v < 0 ? 0 : v;
}

double _hypot(num a, num b) => math.sqrt(
      a.toDouble() * a.toDouble() + b.toDouble() * b.toDouble(),
    );

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
  bool ceilingHeights = false,
}) {
  final axes = pricedAxesFromCells(cells);
  final snappedHeight =
      ceilingHeights ? ceilingSize(heightMm, axes.heights) : null;
  final bucketWidth = nearestSize(widthMm, axes.widths);
  final bucketHeight = ceilingHeights
      ? (snappedHeight ?? nearestSize(heightMm, axes.heights))
      : nearestSize(heightMm, axes.heights);
  final widthBracket = enclosingSizes(widthMm, axes.widths);
  final ({int lo, int hi}) heightBracket;
  if (ceilingHeights && snappedHeight != null) {
    heightBracket = (lo: snappedHeight, hi: snappedHeight);
  } else {
    heightBracket = enclosingSizes(heightMm, axes.heights);
  }
  final lowerWidth = widthBracket.lo;
  final upperWidth = widthBracket.hi;
  final lowerHeight = heightBracket.lo;
  final upperHeight = heightBracket.hi;
  final byKey = <String, StandardPriceCell>{
    for (final cell in cells) '${cell.widthMm}_${cell.heightMm}': cell,
  };
  final match = byKey['${bucketWidth}_$bucketHeight'];
  final rangeMinWidth = axes.widths.isEmpty ? standardSizeMin : axes.widths.first;
  final rangeMaxWidth = axes.widths.isEmpty ? standardSizeMax : axes.widths.last;
  final rangeMinHeight =
      axes.heights.isEmpty ? standardSizeMin : axes.heights.first;
  final rangeMaxHeight =
      axes.heights.isEmpty ? standardSizeMax : axes.heights.last;
  final widthOut =
      axes.widths.isEmpty || !sizeInAxisRange(widthMm, axes.widths);
  final heightOut = axes.heights.isEmpty ||
      (ceilingHeights
          ? snappedHeight == null
          : !sizeInAxisRange(heightMm, axes.heights));
  final outOfRange = widthOut || heightOut;
  final isExactBucket = !outOfRange &&
      axes.widths.contains(widthMm) &&
      axes.heights.contains(heightMm);
  final betweenOnGrid =
      !outOfRange && (lowerWidth != upperWidth || lowerHeight != upperHeight);
  final interpolated = outOfRange
      ? null
      : betweenOnGrid
          ? _interpolateGridPrice(
              byKey: byKey,
              widthMm: widthMm,
              heightMm: heightMm,
              wLo: lowerWidth,
              wHi: upperWidth,
              hLo: lowerHeight,
              hHi: upperHeight,
            )
          : _usableCellPrice(byKey['${lowerWidth}_$lowerHeight']);
  final estimatedPrice =
      outOfRange ? null : interpolated ?? _usableCellPrice(match);

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
    isExactBucket: isExactBucket,
    match: match,
    nearby: nearby.take(8).map((row) => row.cell).toList(growable: false),
    lowerWidth: lowerWidth,
    upperWidth: upperWidth,
    lowerHeight: lowerHeight,
    upperHeight: upperHeight,
    estimatedPrice: estimatedPrice,
    isEstimated: betweenOnGrid && interpolated != null,
    outOfRange: outOfRange,
    rangeMinWidth: rangeMinWidth,
    rangeMaxWidth: rangeMaxWidth,
    rangeMinHeight: rangeMinHeight,
    rangeMaxHeight: rangeMaxHeight,
    highlightCells: _uniqueHighlightCells(
      outOfRange
          ? [
              StandardHighlightCell(
                widthMm: widthMm > rangeMaxWidth
                    ? rangeMaxWidth
                    : widthMm < rangeMinWidth
                        ? rangeMinWidth
                        : lowerWidth,
                heightMm: heightMm > rangeMaxHeight
                    ? rangeMaxHeight
                    : heightMm < rangeMinHeight
                        ? rangeMinHeight
                        : lowerHeight,
              ),
            ]
          : [
              StandardHighlightCell(widthMm: lowerWidth, heightMm: lowerHeight),
              StandardHighlightCell(widthMm: upperWidth, heightMm: lowerHeight),
              StandardHighlightCell(widthMm: lowerWidth, heightMm: upperHeight),
              StandardHighlightCell(widthMm: upperWidth, heightMm: upperHeight),
            ],
    ),
  );
}

String describeSizeLookup(StandardPriceInference inference) {
  final inputWidth = inference.inputWidth;
  final inputHeight = inference.inputHeight;
  final lowerWidth = inference.lowerWidth;
  final upperWidth = inference.upperWidth;
  final lowerHeight = inference.lowerHeight;
  final upperHeight = inference.upperHeight;
  if (inference.outOfRange) {
    final parts = <String>[];
    if (inputWidth > inference.rangeMaxWidth) {
      parts.add('폭 최대 ${inference.rangeMaxWidth}mm');
    }
    if (inputHeight > inference.rangeMaxHeight) {
      parts.add('높이 최대 ${inference.rangeMaxHeight}mm');
    }
    if (inputWidth < inference.rangeMinWidth) {
      parts.add('폭 최소 ${inference.rangeMinWidth}mm');
    }
    if (inputHeight < inference.rangeMinHeight) {
      parts.add('높이 최소 ${inference.rangeMinHeight}mm');
    }
    return '입력 $inputWidth × $inputHeight · ${parts.join(', ')}까지 · 불가';
  }
  final heightSnapped = lowerHeight == upperHeight && inputHeight != lowerHeight;
  final heightSnapText = heightSnapped
      ? '높이 $inputHeight → ${heightDanLabel(lowerHeight)}'
      : '';
  if (inference.isExactBucket) {
    return '격자 $lowerWidth × ${heightDanLabel(lowerHeight)}';
  }
  final widthLabel = lowerWidth == upperWidth
      ? '폭 $lowerWidth'
      : '폭 $lowerWidth~$upperWidth';
  final heightLabel = lowerHeight == upperHeight
      ? '높이 ${heightDanLabel(lowerHeight)}'
      : '높이 $lowerHeight~$upperHeight';
  if (inference.isEstimated) {
    return heightSnapText.isNotEmpty
        ? '입력 $inputWidth × $inputHeight · $widthLabel 사이 추정 · $heightSnapText'
        : '입력 $inputWidth × $inputHeight · $widthLabel × $heightLabel 사이 추정';
  }
  if (heightSnapText.isNotEmpty && lowerWidth == upperWidth) {
    return '입력 $inputWidth × $inputHeight · $heightSnapText';
  }
  if (lowerWidth == upperWidth && lowerHeight == upperHeight) {
    return '입력 $inputWidth × $inputHeight → 표 칸 $lowerWidth × ${heightDanLabel(lowerHeight)}';
  }
  return '입력 $inputWidth × $inputHeight → 가까운 칸 ${inference.bucketWidth} × ${heightDanLabel(inference.bucketHeight)}';
}

class SameSizeModelQuote {
  const SameSizeModelQuote({
    required this.modelId,
    required this.modelName,
    required this.color,
    required this.inference,
  });

  final String modelId;
  final String modelName;
  final String color;
  final StandardPriceInference inference;

  int? get price {
    if (inference.outOfRange) return null;
    final v = inference.estimatedPrice;
    if (v == null || v <= 0) return null;
    return v;
  }

  bool get unavailable => price == null;
}

/// 같은 폭×높이로 분류 안 모델들의 단가.
List<SameSizeModelQuote> sameSizeQuotes({
  required List<({String id, String name, String color})> models,
  required Map<String, List<StandardPriceCell>> cellsByModel,
  required int widthMm,
  required int heightMm,
  bool ceilingHeights = false,
}) {
  if (widthMm <= 0 || heightMm <= 0 || models.isEmpty) return const [];
  return [
    for (final model in models)
      SameSizeModelQuote(
        modelId: model.id,
        modelName: model.name,
        color: model.color,
        inference: inferStandardPrice(
          cells: cellsByModel[model.id] ?? const [],
          widthMm: widthMm,
          heightMm: heightMm,
          ceilingHeights: ceilingHeights,
        ),
      ),
  ];
}

String formatStandardQuoteLine({
  required String categoryName,
  required String modelName,
  required StandardPriceInference inference,
}) {
  final cat = categoryName.trim().isEmpty ? '분류' : categoryName.trim();
  final model = modelName.trim().isEmpty ? '모델' : modelName.trim();
  final size = '${inference.inputWidth}×${inference.inputHeight}';
  final head = '$cat / $model · $size';
  if (inference.outOfRange) return '$head · 표 범위 초과 · 불가';
  final price = inference.estimatedPrice;
  if (price == null || price <= 0) {
    if (!inference.isEstimated && inference.match?.available == false) {
      return '$head · 해당 사이즈 불가';
    }
    return '$head · 단가 없음';
  }
  final won = '${_plainWon(price)}원';
  if (inference.isEstimated) return '$head · $won (사이값 추정)';
  return '$head · $won';
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
