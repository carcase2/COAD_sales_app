import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 테슬라 앱식 하단 액션 독 — 한 손 조작용 고정 컨트롤.
class UxActionDock extends StatelessWidget {
  const UxActionDock({
    super.key,
    required this.children,
    this.flexes,
    this.padding,
  });

  final List<Widget> children;

  /// 각 자식 `Expanded` 비율. 없으면 균등 분할.
  final List<int>? flexes;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      elevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      color: scheme.surfaceContainerLow.withValues(alpha: 0.98),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        padding:
            padding ??
            EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceSm + 2,
              AppTokens.spaceMd,
              AppTokens.spaceSm + bottom,
            ),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                flex: (flexes != null && i < flexes!.length) ? flexes![i] : 1,
                child: children[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 독/카드용 큰 액션 버튼 — 아이콘 위 · 라벨 아래 (좁은 폭에서도 글씨 유지).
class UxDockButton extends StatelessWidget {
  const UxDockButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.color,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final active = enabled && onPressed != null;
    final fg = emphasized
        ? (active ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.38))
        : (active ? accent : scheme.onSurface.withValues(alpha: 0.38));
    final bg = emphasized
        ? (active ? accent : scheme.onSurface.withValues(alpha: 0.12))
        : Colors.transparent;
    final borderColor = emphasized
        ? Colors.transparent
        : accent.withValues(alpha: active ? 0.45 : 0.2);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !active
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTokens.minTouchTarget + 4,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 상태 우선 배너 — 지금 할 일 + 원탭 CTA.
class UxStatusHeroBanner extends StatelessWidget {
  const UxStatusHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.actionLabel = '지금 처리',
    this.tone = UxStatusHeroTone.attention,
    this.onLongPress,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String actionLabel;
  final UxStatusHeroTone tone;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, iconColor, btnBg, btnFg) = switch (tone) {
      UxStatusHeroTone.attention => (
        scheme.errorContainer.withValues(alpha: 0.5),
        scheme.onErrorContainer,
        scheme.error,
        scheme.error,
        scheme.onError,
      ),
      UxStatusHeroTone.info => (
        scheme.tertiaryContainer.withValues(alpha: 0.45),
        scheme.onTertiaryContainer,
        scheme.tertiary,
        scheme.tertiary,
        scheme.onTertiary,
      ),
      UxStatusHeroTone.neutral => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        scheme.onSurface,
        scheme.primary,
        scheme.primary,
        scheme.onPrimary,
      ),
    };

    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final compactPad = compact && ios;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: Padding(
          padding: compact
              ? EdgeInsets.fromLTRB(
                  10,
                  compactPad ? 12 : 8,
                  8,
                  compactPad ? 12 : 8,
                )
              : const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: compact ? (compactPad ? 34 : 28) : 42,
                height: compact ? (compactPad ? 34 : 28) : 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(compact ? 8 : 12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: compact ? (compactPad ? 18 : 16) : 22,
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: fg,
                        height: 1.15,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: fg.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (compact)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: fg.withValues(alpha: 0.7),
                )
              else
                FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onTap();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: btnBg,
                    foregroundColor: btnFg,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum UxStatusHeroTone { attention, info, neutral }

/// 원탭 원형 액션 — 목록 카드용 (전화/문자).
class UxQuickRoundAction extends StatelessWidget {
  const UxQuickRoundAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.tooltip,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Material(
      color: filled ? color : color.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.42,
            color: filled ? scheme.onPrimary : color,
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
