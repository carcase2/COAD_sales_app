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

    final words =
        query.toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final pattern = words.map(RegExp.escape).join('|');
    final regex = RegExp(pattern, caseSensitive: false);
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
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

    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: highlightStyleResolved,
      ));
      start = match.end;
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
