import 'package:flutter/material.dart';

class SearchHighlightText extends StatelessWidget {
  const SearchHighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  TextStyle _resolveBaseStyle(BuildContext context) {
    final theme = Theme.of(context);
    final inherited = DefaultTextStyle.of(context).style;
    final merged = inherited.merge(style ?? theme.textTheme.bodyMedium);
    final color = merged.color ??
        style?.color ??
        inherited.color ??
        theme.colorScheme.onSurface;
    return merged.copyWith(color: color);
  }

  TextStyle _resolveHighlightStyle(TextStyle base) {
    final overlay = highlightStyle ??
        TextStyle(
          backgroundColor: Colors.amber.withValues(alpha: 0.45),
          fontWeight: FontWeight.w700,
        );
    // base(색·크기) 위에 하이라이트 배경만 덧씌움
    return base.merge(overlay).copyWith(color: base.color);
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = _resolveBaseStyle(context);

    if (query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final ranges = searchHighlightRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final highlightStyleResolved = _resolveHighlightStyle(baseStyle);
    final spans = <TextSpan>[];
    var start = 0;

    for (final range in ranges) {
      if (range.$1 > start) {
        spans.add(TextSpan(
          text: text.substring(start, range.$1),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(range.$1, range.$2),
        style: highlightStyleResolved,
      ));
      start = range.$2;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

bool searchTextMatches(String text, String query) =>
    searchHighlightRanges(text, query).isNotEmpty;

/// 일반 부분 일치 + 전화번호처럼 하이픈이 달라도 숫자열 일치.
List<(int, int)> searchHighlightRanges(String text, String query) {
  final words =
      query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty || text.isEmpty) return const [];

  final raw = <(int, int)>[];
  for (final w in words) {
    for (final m in RegExp(RegExp.escape(w), caseSensitive: false).allMatches(text)) {
      raw.add((m.start, m.end));
    }
    final digits = w.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) {
      raw.addAll(_digitMatchRanges(text, digits));
    }
  }
  if (raw.isEmpty) return const [];
  raw.sort((a, b) => a.$1.compareTo(b.$1));

  final merged = <(int, int)>[raw.first];
  for (var i = 1; i < raw.length; i++) {
    final prev = merged.last;
    final cur = raw[i];
    if (cur.$1 <= prev.$2) {
      merged[merged.length - 1] = (prev.$1, cur.$2 > prev.$2 ? cur.$2 : prev.$2);
    } else {
      merged.add(cur);
    }
  }
  return merged;
}

List<(int, int)> _digitMatchRanges(String text, String digits) {
  final idx = <int>[];
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c >= 48 && c <= 57) {
      idx.add(i);
      buf.writeCharCode(c);
    }
  }
  final hay = buf.toString();
  if (hay.length < digits.length) return const [];
  final out = <(int, int)>[];
  var from = 0;
  while (true) {
    final i = hay.indexOf(digits, from);
    if (i < 0) break;
    out.add((idx[i], idx[i + digits.length - 1] + 1));
    from = i + 1;
  }
  return out;
}
