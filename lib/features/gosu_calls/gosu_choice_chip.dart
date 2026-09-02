import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Color? gosuChipColorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// 자동문의고수 접수 선택 칩. 선택 시 채움·체크·굵은 글씨로 구분이 분명하다.
class GosuChoiceChip extends StatelessWidget {
  const GosuChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selectedColor ?? AppTokens.gosuAccent(scheme);
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected ? Colors.white : scheme.onSurface,
        ),
      ),
      selected: selected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      selectedColor: fill,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      side: BorderSide(
        color: selected ? fill : scheme.outline,
        width: selected ? 1.6 : 1,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (v) {
        HapticFeedback.selectionClick();
        onSelected(v);
      },
    );
  }
}

/// 목록용 문의종류·문의방법 뱃지.
class GosuNamedBadge extends StatelessWidget {
  const GosuNamedBadge({super.key, required this.label, this.colorHex});

  final String label;
  final String? colorHex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = gosuChipColorFromHex(colorHex) ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
