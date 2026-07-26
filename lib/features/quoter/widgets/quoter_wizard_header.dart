import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 견적 마법사 상단 단계 칩 (1–4).
class QuoterWizardHeader extends StatelessWidget {
  const QuoterWizardHeader({
    super.key,
    required this.currentStep,
    required this.hasResult,
    required this.onStepTap,
  });

  final int currentStep;
  final bool hasResult;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = scheme.surface;

    Widget stepChip(int step, String label) {
      final accent = quoterStepAccent(step);
      final active = currentStep == step;
      final done = step < currentStep || (step == 4 && hasResult);

      final double activeTint = isDark ? 0.34 : 0.17;
      final double doneTint = isDark ? 0.16 : 0.10;
      final Color bg;
      final Color borderColor;
      final Color stepNumColor;
      final Color nameColor;

      if (active) {
        bg = Color.alphaBlend(accent.withValues(alpha: activeTint), surface);
        borderColor = accent;
        stepNumColor = accent;
        nameColor = scheme.onSurface;
      } else if (done) {
        bg = Color.alphaBlend(accent.withValues(alpha: doneTint), surface);
        borderColor = accent.withValues(alpha: isDark ? 0.55 : 0.42);
        stepNumColor = accent.withValues(alpha: isDark ? 0.95 : 0.92);
        nameColor = scheme.onSurfaceVariant;
      } else {
        bg = scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.65 : 0.55,
        );
        borderColor = scheme.outlineVariant.withValues(
          alpha: isDark ? 0.55 : 0.4,
        );
        stepNumColor = scheme.onSurfaceVariant;
        nameColor = scheme.onSurfaceVariant;
      }

      return Expanded(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onStepTap(step);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: active ? 2 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$step단계',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: stepNumColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        stepChip(1, '종류'),
        const SizedBox(width: 6),
        stepChip(2, '규격'),
        const SizedBox(width: 6),
        stepChip(3, '비용'),
        const SizedBox(width: 6),
        stepChip(4, '결과'),
      ],
    );
  }
}
