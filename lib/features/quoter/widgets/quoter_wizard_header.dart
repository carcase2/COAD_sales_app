import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 견적 마법사 상단 단계 칩 (1–4) — 한 줄·낮은 높이로 본문 공간 확보.
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
      final Color fg;

      if (active) {
        bg = Color.alphaBlend(accent.withValues(alpha: activeTint), surface);
        borderColor = accent;
        fg = accent;
      } else if (done) {
        bg = Color.alphaBlend(accent.withValues(alpha: doneTint), surface);
        borderColor = accent.withValues(alpha: isDark ? 0.55 : 0.42);
        fg = accent.withValues(alpha: isDark ? 0.95 : 0.92);
      } else {
        bg = scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.65 : 0.55,
        );
        borderColor = scheme.outlineVariant.withValues(
          alpha: isDark ? 0.55 : 0.4,
        );
        fg = scheme.onSurfaceVariant;
      }

      return Expanded(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onStepTap(step);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: active ? 1.8 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      height: 1,
                      color: active ? scheme.onSurface : fg,
                    ),
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
        const SizedBox(width: 4),
        stepChip(2, '규격'),
        const SizedBox(width: 4),
        stepChip(3, '비용'),
        const SizedBox(width: 4),
        stepChip(4, '결과'),
      ],
    );
  }
}
