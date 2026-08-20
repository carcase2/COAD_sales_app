import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 이미지 대비 정규화 좌표 (0~1). 세로·가로 명함 모두 AABB.
class NormalizedCardBox {
  const NormalizedCardBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get isPortrait => (bottom - top) >= (right - left);
}

/// 배경과 다른 영역·윤곽으로 명함 테두리를 찾는다. isolate에서 실행.
Future<NormalizedCardBox?> detectBusinessCardBox(Uint8List bytes) {
  return compute(_detectBusinessCardBoxSync, bytes);
}

NormalizedCardBox? _detectBusinessCardBoxSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  var src = decoded;
  const maxSide = 360;
  if (src.width > maxSide || src.height > maxSide) {
    if (src.width >= src.height) {
      src = img.copyResize(src, width: maxSide);
    } else {
      src = img.copyResize(src, height: maxSide);
    }
  }

  final w = src.width;
  final h = src.height;
  if (w < 32 || h < 32) return null;

  final lum = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      lum[y * w + x] =
          (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
    }
  }

  const border = 5;
  var bgSum = 0;
  var bgN = 0;
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < border; y++) {
      bgSum += lum[y * w + x];
      bgN++;
    }
    for (var y = h - border; y < h; y++) {
      bgSum += lum[y * w + x];
      bgN++;
    }
  }
  for (var y = border; y < h - border; y++) {
    for (var x = 0; x < border; x++) {
      bgSum += lum[y * w + x];
      bgN++;
    }
    for (var x = w - border; x < w; x++) {
      bgSum += lum[y * w + x];
      bgN++;
    }
  }
  if (bgN == 0) return null;
  final bg = bgSum / bgN;
  final thresh = 26;

  final mask = List<bool>.filled(w * h, false);
  var on = 0;
  for (var i = 0; i < lum.length; i++) {
    if ((lum[i] - bg).abs() >= thresh) {
      mask[i] = true;
      on++;
    }
  }
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final gx = lum[i + 1] - lum[i - 1];
      final gy = lum[i + w] - lum[i - w];
      if (gx.abs() + gy.abs() >= 48 && !mask[i]) {
        mask[i] = true;
        on++;
      }
    }
  }

  final frac = on / (w * h);
  if (frac < 0.035 || frac > 0.93) return null;

  final rowHits = List<int>.filled(h, 0);
  final colHits = List<int>.filled(w, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!mask[y * w + x]) continue;
      rowHits[y]++;
      colHits[x]++;
    }
  }

  final rowSpan = longestRunAbove(rowHits, (w * 0.10).round());
  final colSpan = longestRunAbove(colHits, (h * 0.10).round());
  if (rowSpan == null || colSpan == null) return null;

  var top = rowSpan.$1;
  var bottom = rowSpan.$2;
  var left = colSpan.$1;
  var right = colSpan.$2;

  final bw = right - left + 1;
  final bh = bottom - top + 1;
  if (bw < w * 0.18 || bh < h * 0.18) return null;
  if (bw > w * 0.98 && bh > h * 0.98) return null;

  const pad = 0.012;
  final nl = math.max(0.0, left / w - pad);
  final nt = math.max(0.0, top / h - pad);
  final nr = math.min(1.0, (right + 1) / w + pad);
  final nb = math.min(1.0, (bottom + 1) / h + pad);
  if (nr - nl < 0.16 || nb - nt < 0.16) return null;

  return NormalizedCardBox(left: nl, top: nt, right: nr, bottom: nb);
}

/// [hist]에서 [minHits] 이상인 가장 긴 연속 구간.
(int, int)? longestRunAbove(List<int> hist, int minHits) {
  var bestL = 0;
  var bestR = -1;
  var curL = -1;
  for (var i = 0; i <= hist.length; i++) {
    final on = i < hist.length && hist[i] >= minHits;
    if (on) {
      if (curL < 0) curL = i;
    } else if (curL >= 0) {
      if (i - 1 - curL > bestR - bestL) {
        bestL = curL;
        bestR = i - 1;
      }
      curL = -1;
    }
  }
  if (bestR < bestL) return null;
  return (bestL, bestR);
}
