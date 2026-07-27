import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 1단계 · 셔터 종류 — 낮은 높이 2열 그리드 (본문 공간 최대화).
class QuoterTypeSelector extends StatelessWidget {
  const QuoterTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  final ShutterType selectedType;
  final ValueChanged<ShutterType> onSelected;

  static const double _rowH = 44;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final a = quoterStepAccent(1);
    final scheme = Theme.of(context).colorScheme;
    final unselectedFill = scheme.surfaceContainerHighest;
    final types = ShutterType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.view_module_rounded, size: 14, color: a),
              const SizedBox(width: 5),
              Text(
                '셔터 종류',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: a,
                ),
              ),
              const Spacer(),
              Text(
                '탭하면 바로 규격으로',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // 고정 높이 3행 — 화면을 채우지 않고 컴팩트하게
        for (var r = 0; r < 3; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          SizedBox(
            height: _rowH,
            child: Row(
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: _TypeChip(
                      type: types[r * 2 + c],
                      selected: selectedType == types[r * 2 + c],
                      unselectedFill: unselectedFill,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelected(types[r * 2 + c]);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.unselectedFill,
    required this.onTap,
  });

  final ShutterType type;
  final bool selected;
  final Color unselectedFill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = QuoterTypeStyle.color(type);
    final icon = QuoterTypeStyle.icon(type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : unselectedFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.28),
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  QuoterTypeStyle.label(type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: selected
                        ? Colors.white
                        : color.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
