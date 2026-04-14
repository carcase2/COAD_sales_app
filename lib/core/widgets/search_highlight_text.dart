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

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyMedium;
    final effectiveHighlightStyle = highlightStyle ??
        TextStyle(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );

    // Split query into individual keywords (space-separated)
    final words = query.toLowerCase().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) {
      return Text(
        text,
        style: effectiveStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Create a regex that matches any of the words (case insensitive)
    final pattern = words.map((w) => RegExp.escape(w)).join('|');
    final regex = RegExp(pattern, caseSensitive: false);

    final List<TextSpan> spans = [];
    int start = 0;

    // Use allMatches to find every occurrence of any keyword
    final matches = regex.allMatches(text).toList();
    
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: effectiveStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: effectiveHighlightStyle,
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: effectiveStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
