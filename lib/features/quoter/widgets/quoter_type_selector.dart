import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 1단계 · 셔터 종류 그리드.
class QuoterTypeSelector extends StatelessWidget {
  const QuoterTypeSelector({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  final ShutterType selectedType;
  final ValueChanged<ShutterType> onSelected;

  @override
  Widget build(BuildContext context) {
    final a = quoterStepAccent(1);
    final scheme = Theme.of(context).colorScheme;
    final unselectedFill = scheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.view_module_rounded, size: 18, color: a),
              const SizedBox(width: 8),
              Text(
                '1단계 · 셔터 종류 선택',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: a,
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.9,
          children: ShutterType.values.map((t) {
            final isSelected = selectedType == t;
            final color = QuoterTypeStyle.color(t);
            final icon = QuoterTypeStyle.icon(t);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(t);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? color : unselectedFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.25),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        QuoterTypeStyle.label(t),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : color.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
