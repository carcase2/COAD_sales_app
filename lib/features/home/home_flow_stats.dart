import 'package:coad_customer_calls/features/home/home_hub_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 홈 흐름 탭 — 접수/미통화/팔로우/업데이트 통계 카드.
class HomeMiniStatsWidget extends StatefulWidget {
  const HomeMiniStatsWidget({
    super.key,
    required this.receptionLabel,
    required this.incompleteLabel,
    required this.followLabel,
    required this.updatedLabel,
    required this.today,
    required this.incomplete,
    required this.todayFollow,
    required this.updated,
    this.followProgressHint,
    required this.uncalledRateText,
    required this.avgFirstResponseText,
    required this.onTapToday,
    required this.onTapIncomplete,
    required this.onTapTodayFollow,
    required this.onTapUpdated,
    required this.onTapUncalledRate,
    required this.onTapFirstResponse,
    this.onLongPressToday,
    this.onLongPressIncomplete,
    this.onLongPressTodayFollow,
    this.onLongPressUpdated,
    this.compact = false,
    this.headerAlerts = const [],
  });

  final String receptionLabel;
  final String incompleteLabel;
  final String followLabel;
  final String updatedLabel;
  final int today;
  final int incomplete;
  final int todayFollow;
  final int updated;
  final String? followProgressHint;
  final String uncalledRateText;
  final String avgFirstResponseText;
  final VoidCallback onTapToday;
  final VoidCallback onTapIncomplete;
  final VoidCallback onTapTodayFollow;
  final VoidCallback onTapUpdated;
  final VoidCallback? onLongPressToday;
  final VoidCallback? onLongPressIncomplete;
  final VoidCallback? onLongPressTodayFollow;
  final VoidCallback? onLongPressUpdated;
  final VoidCallback onTapUncalledRate;
  final VoidCallback onTapFirstResponse;
  final bool compact;
  final List<Widget> headerAlerts;

  @override
  State<HomeMiniStatsWidget> createState() => _HomeMiniStatsWidgetState();
}

bool _isBlankAlert(Widget w) =>
    w is SizedBox && (w.width ?? 0) == 0 && (w.height ?? 0) == 0;

class _HomeMiniStatsWidgetState extends State<HomeMiniStatsWidget> {
  bool _qualityExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = widget.compact;
    const gap = 8.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: HomeHubVisual.elevatedCard(scheme),
      child: Column(
        children: [
          if (widget.headerAlerts.isNotEmpty) ...[
            for (final alert in widget.headerAlerts)
              if (!_isBlankAlert(alert)) ...[alert, SizedBox(height: gap)],
          ],
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.inbox_rounded,
                    label: widget.receptionLabel,
                    value: widget.today.toString(),
                    color: scheme.primary,
                    onTap: widget.onTapToday,
                    onLongPress: widget.onLongPressToday,
                    compact: compact,
                    semanticsLabel:
                        '${widget.receptionLabel} ${widget.today}건. 탭하면 목록, 메뉴로 담당자 선택',
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.phone_missed_rounded,
                    label: widget.incompleteLabel,
                    value: widget.incomplete.toString(),
                    color: scheme.error,
                    onTap: widget.onTapIncomplete,
                    onLongPress: widget.onLongPressIncomplete,
                    compact: compact,
                    semanticsLabel:
                        '${widget.incompleteLabel} ${widget.incomplete}건. 탭하면 목록, 메뉴로 담당자 선택',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.event_available_rounded,
                    label: widget.followLabel,
                    value: widget.todayFollow.toString(),
                    color: scheme.tertiary,
                    onTap: widget.onTapTodayFollow,
                    onLongPress: widget.onLongPressTodayFollow,
                    compact: compact,
                    semanticsLabel:
                        '${widget.followLabel} ${widget.todayFollow}건. 탭하면 목록, 메뉴로 담당자 선택',
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.update_rounded,
                    label: widget.updatedLabel,
                    value: widget.updated.toString(),
                    color: scheme.secondary,
                    onTap: widget.onTapUpdated,
                    onLongPress: widget.onLongPressUpdated,
                    compact: compact,
                    semanticsLabel:
                        '${widget.updatedLabel} ${widget.updated}건. 탭하면 목록, 메뉴로 담당자 선택',
                  ),
                ),
              ],
            ),
          ),
          if (_qualityExpanded) ...[
            const SizedBox(height: 10),
            if (widget.followProgressHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(
                      color: scheme.tertiary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: widget.onTapTodayFollow,
                    onLongPress: widget.onLongPressTodayFollow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.followProgressHint!,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InsightItem(
                      label: '미통화율',
                      value: widget.uncalledRateText,
                      color: scheme.error,
                      onTap: widget.onTapUncalledRate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightItem(
                      label: '첫 응답 평균',
                      value: widget.avgFirstResponseText,
                      color: scheme.secondary,
                      onTap: widget.onTapFirstResponse,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 2),
          TextButton.icon(
            onPressed: () =>
                setState(() => _qualityExpanded = !_qualityExpanded),
            icon: Icon(
              _qualityExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: Text(
              _qualityExpanded ? '품질 지표 접기' : '품질 지표',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSupportMiniStatsWidget extends StatelessWidget {
  const HomeSupportMiniStatsWidget({
    super.key,
    required this.receptionLabel,
    required this.pendingLabel,
    required this.visitLabel,
    required this.updatedLabel,
    required this.reception,
    required this.pending,
    required this.visits,
    required this.updated,
    required this.onTapReception,
    required this.onTapPending,
    required this.onTapVisit,
    required this.onTapUpdated,
    this.allPending = 0,
    this.onTapAllPending,
    this.allIncomplete = 0,
    this.onTapAllIncomplete,
    this.headerAlert,
    this.compact = true,
  });

  final String receptionLabel;
  final String pendingLabel;
  final String visitLabel;
  final String updatedLabel;
  final int reception;
  final int pending;
  final int visits;
  final int updated;
  final VoidCallback onTapReception;
  final VoidCallback onTapPending;
  final VoidCallback onTapVisit;
  final VoidCallback onTapUpdated;
  final int allPending;
  final VoidCallback? onTapAllPending;
  final int allIncomplete;
  final VoidCallback? onTapAllIncomplete;
  final Widget? headerAlert;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color.lerp(const Color(0xFF0D9488), scheme.primary, 0.18)!;
    const gap = 8.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: HomeHubVisual.elevatedCard(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerAlert != null) ...[headerAlert!, SizedBox(height: gap)],
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.handyman_outlined,
                    label: receptionLabel,
                    value: reception.toString(),
                    color: accent,
                    onTap: onTapReception,
                    compact: compact,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.pending_actions_rounded,
                    label: pendingLabel,
                    value: pending.toString(),
                    color: scheme.error,
                    onTap: onTapPending,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.event_available_rounded,
                    label: visitLabel,
                    value: visits.toString(),
                    color: scheme.tertiary,
                    onTap: onTapVisit,
                    compact: compact,
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: _FlowStatTile(
                    icon: Icons.update_rounded,
                    label: updatedLabel,
                    value: updated.toString(),
                    color: scheme.secondary,
                    onTap: onTapUpdated,
                    compact: compact,
                  ),
                ),
              ],
            ),
          ),
          if (onTapAllPending != null || onTapAllIncomplete != null) ...[
            SizedBox(height: gap),
            Row(
              children: [
                if (onTapAllPending != null)
                  Expanded(
                    child: _HomeWideStat(
                      icon: Icons.phone_callback_rounded,
                      label: '전체 미처리',
                      count: allPending,
                      accent: accent,
                      alert: allPending > 0,
                      onTap: onTapAllPending!,
                    ),
                  ),
                if (onTapAllPending != null && onTapAllIncomplete != null)
                  SizedBox(width: gap),
                if (onTapAllIncomplete != null)
                  Expanded(
                    child: _HomeWideStat(
                      icon: Icons.assignment_late_outlined,
                      label: '전체 미완료',
                      count: allIncomplete,
                      accent: accent,
                      alert: allIncomplete > 0,
                      onTap: onTapAllIncomplete!,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeWideStat extends StatelessWidget {
  const _HomeWideStat({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.alert,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: alert
          ? scheme.errorContainer.withValues(alpha: 0.7)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: alert ? scheme.error : accent),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: alert ? scheme.error : accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowStatTile extends StatelessWidget {
  const _FlowStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticsLabel ?? '$label $value',
      child: Material(
        color: color.withValues(alpha: 0.06),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
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
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: _StatItem(
                    icon: icon,
                    label: label,
                    value: value,
                    color: color,
                  ),
                ),
              ),
              if (onLongPress != null && !compact)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    tooltip: '담당자 선택',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    iconSize: 16,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onLongPress!();
                    },
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
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

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label $value',
      child: Material(
        color: color.withValues(alpha: 0.05),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.2,
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// 흐름 탭 로딩/네트워크 오류 패널.
class HomeFlowErrorPanel extends StatelessWidget {
  const HomeFlowErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.error, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

/// 홈 섹션 스와이프 후 상태 유지 — 재방문 시 재빌드 비용 절감.
class HomeKeepAliveSection extends StatefulWidget {
  const HomeKeepAliveSection({super.key, required this.child});

  final Widget child;

  @override
  State<HomeKeepAliveSection> createState() => _HomeKeepAliveSectionState();
}

class _HomeKeepAliveSectionState extends State<HomeKeepAliveSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
