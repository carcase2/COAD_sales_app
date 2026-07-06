import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kGeneralScheduleAllAssignees = '전체';

/// 본사일반 달력 보기 — 주간 / 월간.
enum GeneralScheduleCalendarView { week, month }

/// 주간·월간 전환 토글.
class GeneralScheduleCalendarViewToggle extends StatelessWidget {
  const GeneralScheduleCalendarViewToggle({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final GeneralScheduleCalendarView view;
  final ValueChanged<GeneralScheduleCalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: SegmentedButton<GeneralScheduleCalendarView>(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: GeneralScheduleCalendarView.week,
            label: Text('주간'),
            icon: Icon(Icons.view_week_rounded, size: 17),
          ),
          ButtonSegment(
            value: GeneralScheduleCalendarView.month,
            label: Text('월간'),
            icon: Icon(Icons.calendar_month_rounded, size: 17),
          ),
        ],
        selected: {view},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

String generalScheduleAssigneeLabel(GeneralScheduleCell cell) {
  final name = cell.userName?.trim();
  return name != null && name.isNotEmpty ? name : '미지정';
}

bool generalScheduleMatchesAssigneeFilter(
  GeneralScheduleCell? cell,
  String assigneeFilter,
) {
  if (assigneeFilter == kGeneralScheduleAllAssignees) return true;
  if (cell == null) return true;
  return generalScheduleAssigneeLabel(cell) == assigneeFilter;
}

TextStyle generalScheduleSlotLabelStyle({
  required double fontSize,
  required Color color,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    height: 1.2,
    leadingDistribution: TextLeadingDistribution.even,
    color: color,
  );
}

/// 가로 6칸·월간 한 줄 현장명에 필요한 최소 높이.
double generalScheduleSlotRowHeight(double fontSize) => fontSize + 10;

List<GeneralScheduleCell?> filterDaySlotsForAssignee(
  List<GeneralScheduleCell?> slots,
  String assigneeFilter,
) {
  if (assigneeFilter == kGeneralScheduleAllAssignees) return slots;
  return slots
      .map(
        (cell) => generalScheduleMatchesAssigneeFilter(cell, assigneeFilter)
            ? cell
            : null,
      )
      .toList();
}

/// 일별 슬롯을 담당자별 섹션으로 묶어 표시 (로그인 담당자 우선·펼침).
class GeneralScheduleAssigneeFilterBar extends StatelessWidget {
  const GeneralScheduleAssigneeFilterBar({
    super.key,
    required this.assignees,
    required this.counts,
    required this.selected,
    required this.onSelected,
    this.colorForAssignee,
    this.horizontalPadding = 12,
  });

  final List<String> assignees;
  final Map<String, int> counts;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color Function(String assignee)? colorForAssignee;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color colorOf(String name) =>
        colorForAssignee?.call(name) ?? scheme.primary;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: assignees.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final assignee = assignees[i];
          final count = counts[assignee] ?? 0;
          final isSelected = selected == assignee;
          final color = colorOf(assignee);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(assignee);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.16)
                    : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.5)
                      : scheme.outlineVariant.withValues(alpha: 0.35),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    assignee,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 담당자 목록 정렬 — 전체 → 로그인 사용자 → 나머지.
List<String> sortGeneralScheduleAssignees(
  Iterable<String> names, {
  String? loginUserName,
}) {
  final login = loginUserName?.trim();
  final list = names.toList();
  list.sort((a, b) {
    if (a == kGeneralScheduleAllAssignees) return -1;
    if (b == kGeneralScheduleAllAssignees) return 1;
    if (login != null && login.isNotEmpty) {
      if (a == login) return -1;
      if (b == login) return 1;
    }
    if (a == '미지정') return 1;
    if (b == '미지정') return -1;
    return a.compareTo(b);
  });
  return list;
}

/// 긴 현장명 자동 가로 스크롤 — ScrollController 기반 (안전).
class GeneralScheduleAutoScrollText extends StatefulWidget {
  const GeneralScheduleAutoScrollText({
    super.key,
    required this.text,
    required this.style,
    this.scrollMsPerPixel = 90,
    this.pauseMs = 1200,
  });

  final String text;
  final TextStyle style;
  /// 픽셀당 스크롤 시간(ms) — 클수록 느림.
  final double scrollMsPerPixel;
  final int pauseMs;

  @override
  State<GeneralScheduleAutoScrollText> createState() =>
      _GeneralScheduleAutoScrollTextState();
}

class _GeneralScheduleAutoScrollTextState
    extends State<GeneralScheduleAutoScrollText> {
  static const _marqueeGap = 24.0;

  final _scrollController = ScrollController();
  int _loopGeneration = 0;
  double _lastViewWidth = -1;
  double _segmentWidth = 0;

  @override
  void initState() {
    super.initState();
    _scheduleLoop();
  }

  @override
  void didUpdateWidget(covariant GeneralScheduleAutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _scheduleLoop();
    }
  }

  @override
  void dispose() {
    _loopGeneration++;
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleLoop() {
    _loopGeneration++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_runLoop(_loopGeneration));
      }
    });
  }

  Future<void> _runLoop(int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || generation != _loopGeneration) return;

    for (var attempt = 0; attempt < 40; attempt++) {
      if (!mounted || generation != _loopGeneration) return;
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      }
      if (_segmentWidth > 1) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted ||
        generation != _loopGeneration ||
        !_scrollController.hasClients ||
        _segmentWidth <= 1) {
      return;
    }

    final duration = Duration(
      milliseconds: (_segmentWidth * widget.scrollMsPerPixel).round().clamp(
            3500,
            16000,
          ),
    );

    while (mounted && generation == _loopGeneration) {
      await Future<void>.delayed(Duration(milliseconds: widget.pauseMs));
      if (!mounted || generation != _loopGeneration) return;
      if (!_scrollController.hasClients || _segmentWidth <= 1) return;

      try {
        await _scrollController.animateTo(
          _segmentWidth,
          duration: duration,
          curve: Curves.linear,
        );
      } catch (_) {
        return;
      }

      if (!mounted || generation != _loopGeneration) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    }
  }

  double _measureTextWidth(String label, TextStyle textStyle) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  Widget _buildLabelText(String label, TextStyle textStyle) {
    return Text(
      label,
      style: textStyle,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.text.trim();
    if (label.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        final viewHeight = constraints.maxHeight;
        if (!viewWidth.isFinite || viewWidth <= 0) {
          return Text(
            label,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        if (viewWidth != _lastViewWidth) {
          _lastViewWidth = viewWidth;
          _segmentWidth = 0;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleLoop();
          });
        }

        final boxHeight =
            viewHeight.isFinite && viewHeight > 0 ? viewHeight : 14.0;
        final textStyle = widget.style;
        final textWidth = _measureTextWidth(label, textStyle);
        final needsScroll = textWidth > viewWidth + 0.5;

        if (!needsScroll) {
          _segmentWidth = 0;
          return SizedBox(
            width: viewWidth,
            height: boxHeight,
            child: ClipRect(
              child: Center(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          );
        }

        _segmentWidth = textWidth + _marqueeGap;

        return SizedBox(
          width: viewWidth,
          height: boxHeight,
          child: ClipRect(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLabelText(label, textStyle),
                    const SizedBox(width: _marqueeGap),
                    _buildLabelText(label, textStyle),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 월간 달력 날짜 칸 — 현장명 세로 나열 + 각 줄 가로 자동 스크롤.
class GeneralScheduleMonthCellSiteList extends StatelessWidget {
  const GeneralScheduleMonthCellSiteList({
    super.key,
    required this.slots,
    required this.scheme,
    this.assigneeFilter = kGeneralScheduleAllAssignees,
    this.siteFontSize = 8.5,
    this.siteRowHeight = 18,
    this.siteRowGap = 1,
  });

  final List<GeneralScheduleCell?> slots;
  final ColorScheme scheme;
  final String assigneeFilter;
  final double siteFontSize;
  final double siteRowHeight;
  final double siteRowGap;

  @override
  Widget build(BuildContext context) {
    final safeSlots = normalizeGeneralScheduleDaySlots(slots);
    final rows = <Widget>[];

    for (final cell in safeSlots) {
      if (cell == null) continue;
      if (!generalScheduleMatchesAssigneeFilter(cell, assigneeFilter)) continue;
      rows.add(_siteRow(cell, scheme));
    }

    if (rows.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: Text(
          '—',
          style: TextStyle(
            fontSize: 8,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const ClampingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, _) => SizedBox(height: siteRowGap),
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _siteRow(GeneralScheduleCell cell, ColorScheme scheme) {
    final accent = parseGeneralScheduleUserColor(
          cell.userColor,
          fallback: scheme.primary,
        ) ??
        scheme.primary;
    final site = cell.site.trim();
    final textStyle = generalScheduleSlotLabelStyle(
      fontSize: siteFontSize,
      color: scheme.onSurface,
    );
    final rowHeight = siteRowHeight < generalScheduleSlotRowHeight(siteFontSize)
        ? generalScheduleSlotRowHeight(siteFontSize)
        : siteRowHeight;

    return SizedBox(
      height: rowHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        clipBehavior: Clip.hardEdge,
        child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: rowHeight - 4,
                margin: const EdgeInsets.only(left: 1),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: GeneralScheduleAutoScrollText(
                  text: site.isEmpty ? '—' : site,
                  scrollMsPerPixel: 100,
                  pauseMs: 1400,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// 주간 날짜 스트립용 6칸 점 표시 (현장명 없음).
class GeneralScheduleStripSlotDots extends StatelessWidget {
  const GeneralScheduleStripSlotDots({
    super.key,
    required this.slots,
    required this.scheme,
    this.assigneeFilter = kGeneralScheduleAllAssignees,
    this.onPrimary = false,
  });

  final List<GeneralScheduleCell?> slots;
  final ColorScheme scheme;
  final String assigneeFilter;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final safeSlots = normalizeGeneralScheduleDaySlots(slots);
    return Row(
      children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
        final cell = safeSlots[i];
        final visible = generalScheduleMatchesAssigneeFilter(
          cell,
          assigneeFilter,
        );
        final filled = cell != null && visible;
        final active = filled ? cell : null;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(
              right: i < kGeneralScheduleSlotsPerDay - 1 ? 1 : 0,
            ),
            decoration: BoxDecoration(
              color: filled
                  ? (onPrimary
                      ? scheme.onPrimary
                      : (parseGeneralScheduleUserColor(
                            active?.userColor,
                            fallback: scheme.primary,
                          ) ?? scheme.primary))
                  : (onPrimary
                      ? scheme.onPrimary.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}

/// 날짜 칸·일별 보기용 가로 6칸 현장명.
class GeneralScheduleHorizontalSlotRow extends StatelessWidget {
  const GeneralScheduleHorizontalSlotRow({
    super.key,
    required this.slots,
    required this.scheme,
    this.assigneeFilter = kGeneralScheduleAllAssignees,
    this.compact = false,
    this.onPrimary = false,
    this.height = 36,
    this.slotGap,
    this.onSlotTap,
  });

  final List<GeneralScheduleCell?> slots;
  final ColorScheme scheme;
  final String assigneeFilter;
  final bool compact;
  final bool onPrimary;
  final double height;
  final double? slotGap;
  final void Function(int slotIndex, GeneralScheduleCell? cell)? onSlotTap;

  @override
  Widget build(BuildContext context) {
    final gap = slotGap ?? (compact ? 1.0 : 2.0);
    final fontSize = compact ? 7.0 : 9.5;
    final rowHeight = height < generalScheduleSlotRowHeight(fontSize)
        ? generalScheduleSlotRowHeight(fontSize)
        : height;
    final safeSlots = normalizeGeneralScheduleDaySlots(slots);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
          final cell = safeSlots[i];
          final visible = generalScheduleMatchesAssigneeFilter(
            cell,
            assigneeFilter,
          );
          final filled = cell != null && visible;
          final active = filled ? cell : null;
          final siteLabel = (active?.site ?? '').trim();
          final accent = filled
              ? (onPrimary
                  ? scheme.onPrimary
                  : (parseGeneralScheduleUserColor(
                        active?.userColor,
                        fallback: scheme.primary,
                      ) ?? scheme.primary))
              : scheme.outlineVariant;

          final radius = BorderRadius.circular(compact ? 2 : 4);
          final child = ClipRRect(
            borderRadius: radius,
            clipBehavior: Clip.hardEdge,
            child: DecoratedBox(
            decoration: BoxDecoration(
              color: filled
                  ? (onPrimary
                      ? accent.withValues(alpha: 0.32)
                      : accent.withValues(alpha: 0.18))
                  : (onPrimary
                      ? scheme.onPrimary.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest
                          .withValues(alpha: 0.75)),
              borderRadius: radius,
              border: Border.all(
                color: filled
                    ? accent.withValues(alpha: onPrimary ? 0.55 : 0.4)
                    : scheme.outlineVariant.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: filled && siteLabel.isNotEmpty
                  ? GeneralScheduleAutoScrollText(
                      text: siteLabel,
                      scrollMsPerPixel: 95,
                      pauseMs: 1400,
                      style: generalScheduleSlotLabelStyle(
                        fontSize: fontSize,
                        color: onPrimary ? Colors.white : accent,
                      ),
                    )
                  : Center(
                      child: Text(
                        compact ? '·' : '+',
                        style: TextStyle(
                          fontSize: compact ? 8 : 11,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          color: onPrimary
                              ? scheme.onPrimary.withValues(alpha: 0.45)
                              : scheme.onSurfaceVariant
                                  .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
            ),
          ),
          );

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i < kGeneralScheduleSlotsPerDay - 1 ? gap : 0,
              ),
              child: onSlotTap == null
                  ? child
                  : Material(
                      color: Colors.transparent,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSlotTap!(i, cell),
                        borderRadius:
                            BorderRadius.circular(compact ? 2 : 4),
                        child: child,
                      ),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

/// 메인 화면·월간 보기 공통 월간 통계 요약 (펼치기 → 시트).
class GeneralScheduleCollapsibleMonthStats extends StatelessWidget {
  const GeneralScheduleCollapsibleMonthStats({
    super.key,
    required this.stats,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 8, 2),
  });

  final GeneralScheduleMonthStats stats;
  final EdgeInsets margin;

  void _openDetailSheet(BuildContext context) {
    showGeneralScheduleMonthStatsSheet(context, stats);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthPct = (stats.occupancyRate * 100).round();
    final summary =
        '${formatGeneralScheduleMonthTitle(stats.year, stats.month)} '
        '${stats.usedSlots}/${stats.totalSlots} · 남은 ${stats.emptySlots} ($monthPct%)';

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openDetailSheet(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: stats.occupancyRate.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _MonthStatsActionChip(
              icon: Icons.bar_chart_rounded,
              label: '펼치기',
              onPressed: () => _openDetailSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showGeneralScheduleMonthStatsSheet(
  BuildContext context,
  GeneralScheduleMonthStats stats,
) {
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.38,
        maxChildSize: 0.88,
        builder: (context, scrollController) {
          return Material(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '월간 통계',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      GeneralScheduleMonthStatsDetail(stats: stats),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// 월간 통계 상세 본문.
class GeneralScheduleMonthStatsDetail extends StatelessWidget {
  const GeneralScheduleMonthStatsDetail({
    super.key,
    required this.stats,
  });

  final GeneralScheduleMonthStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthPct = (stats.occupancyRate * 100).round();
    final summary =
        '${formatGeneralScheduleMonthTitle(stats.year, stats.month)} '
        '${stats.usedSlots}/${stats.totalSlots} · 남은 ${stats.emptySlots} ($monthPct%)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompactStatTile(
                label: '전체',
                value: '${stats.totalSlots}',
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _CompactStatTile(
                label: '사용',
                value: '${stats.usedSlots}',
                color: scheme.tertiary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _CompactStatTile(
                label: '남음',
                value: '${stats.emptySlots}',
                color: stats.emptySlots == 0
                    ? scheme.error
                    : const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stats.occupancyRate.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        if (stats.byUser.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '담당자별 칸 수',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          ...stats.byUser.take(12).map((u) {
            final accent = parseGeneralScheduleUserColor(
              u.color,
              fallback: scheme.primary,
            )!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: accent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${u.count}칸',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: accent,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _MonthStatsActionChip extends StatelessWidget {
  const _MonthStatsActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.surfaceContainerHigh;
    final fg = scheme.onSurfaceVariant;

    return Material(
      color: bg,
      shadowColor: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatTile extends StatelessWidget {
  const _CompactStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 일별 슬롯을 담당자별 섹션으로 묶어 표시 (로그인 담당자 우선·펼침).
class GeneralScheduleAssigneeGroupedDayList extends StatefulWidget {
  const GeneralScheduleAssigneeGroupedDayList({
    super.key,
    required this.daySlots,
    required this.searchQuery,
    required this.assigneeFilter,
    required this.onSlotTap,
    required this.slotHeight,
    this.loginUserName,
  });

  final List<GeneralScheduleCell?> daySlots;
  final String searchQuery;
  final String assigneeFilter;
  final void Function(int slotIndex, GeneralScheduleCell? cell) onSlotTap;
  final double slotHeight;
  final String? loginUserName;

  @override
  State<GeneralScheduleAssigneeGroupedDayList> createState() =>
      _GeneralScheduleAssigneeGroupedDayListState();
}

class _GeneralScheduleAssigneeGroupedDayListState
    extends State<GeneralScheduleAssigneeGroupedDayList> {
  late Set<String> _expandedGroups;

  @override
  void initState() {
    super.initState();
    _expandedGroups = _defaultExpanded();
  }

  @override
  void didUpdateWidget(covariant GeneralScheduleAssigneeGroupedDayList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loginUserName != widget.loginUserName ||
        oldWidget.assigneeFilter != widget.assigneeFilter) {
      _expandedGroups = _defaultExpanded();
    }
  }

  Set<String> _defaultExpanded() {
    final login = widget.loginUserName?.trim();
    if (login != null && login.isNotEmpty) {
      return {login};
    }
    return {};
  }

  void _toggleGroup(String key) {
    setState(() {
      if (_expandedGroups.contains(key)) {
        _expandedGroups.remove(key);
      } else {
        _expandedGroups.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = <({int index, GeneralScheduleCell? cell})>[];

    for (var i = 0; i < widget.daySlots.length; i++) {
      final cell = widget.daySlots[i];
      if (!generalScheduleMatchesAssigneeFilter(cell, widget.assigneeFilter)) {
        continue;
      }
      entries.add((index: i, cell: cell));
    }

    if (widget.assigneeFilter != kGeneralScheduleAllAssignees) {
      return _buildFlatList(context, entries);
    }

    final groups = <String, List<({int index, GeneralScheduleCell? cell})>>{};
    final groupOrder = <String>[];

    for (final entry in entries) {
      final key = entry.cell == null
          ? '_empty'
          : generalScheduleAssigneeLabel(entry.cell!);
      groups.putIfAbsent(key, () {
        groupOrder.add(key);
        return [];
      });
      groups[key]!.add(entry);
    }

    final login = widget.loginUserName?.trim();
    groupOrder.sort((a, b) {
      if (a == '_empty') return 1;
      if (b == '_empty') return -1;
      if (login != null && login.isNotEmpty) {
        if (a == login) return -1;
        if (b == login) return 1;
      }
      return a.compareTo(b);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final groupKey in groupOrder) ...[
          if (groupKey == '_empty')
            _CollapsibleSectionHeader(
              title: '빈 칸',
              count: groups[groupKey]!.length,
              color: scheme.onSurfaceVariant,
              expanded: _expandedGroups.contains(groupKey),
              onTap: () => _toggleGroup(groupKey),
            )
          else
            _CollapsibleSectionHeader(
              title: '$groupKey 담당',
              count: groups[groupKey]!
                  .where((e) => e.cell != null)
                  .length,
              color: _assigneeColorFromGroup(groups[groupKey]!, scheme),
              expanded: _expandedGroups.contains(groupKey),
              isLoginUser: login != null && groupKey == login,
              onTap: () => _toggleGroup(groupKey),
            ),
          if (_expandedGroups.contains(groupKey))
            for (final entry in groups[groupKey]!) ...[
              SizedBox(
                height: widget.slotHeight,
                child: GeneralScheduleSlotLaneCard(
                  slotIndex: entry.index,
                  cell: entry.cell,
                  searchQuery: widget.searchQuery,
                  compact: true,
                  onTap: () => widget.onSlotTap(entry.index, entry.cell),
                ),
              ),
              const SizedBox(height: 2),
            ],
        ],
      ],
    );
  }

  Widget _buildFlatList(
    BuildContext context,
    List<({int index, GeneralScheduleCell? cell})> entries,
  ) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          '선택한 담당자의 일정이 없습니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          SizedBox(
            height: widget.slotHeight,
            child: GeneralScheduleSlotLaneCard(
              slotIndex: entry.index,
              cell: entry.cell,
              searchQuery: widget.searchQuery,
              compact: true,
              onTap: () => widget.onSlotTap(entry.index, entry.cell),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  Color _assigneeColorFromGroup(
    List<({int index, GeneralScheduleCell? cell})> group,
    ColorScheme scheme,
  ) {
    for (final e in group) {
      if (e.cell != null) {
        return parseGeneralScheduleUserColor(
              e.cell!.userColor,
              fallback: scheme.primary,
            )!;
      }
    }
    return scheme.primary;
  }
}

class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.expanded,
    required this.onTap,
    this.isLoginUser = false,
  });

  final String title;
  final int count;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;
  final bool isLoginUser;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 6, 0, 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: expanded ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: expanded ? 0.35 : 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 4),
              if (isLoginUser)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.person_rounded, size: 14, color: color),
                ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Text(
                '$count건',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 슬롯 카드 — screen에서 분리해 그룹 리스트와 공유.
class GeneralScheduleSlotLaneCard extends StatelessWidget {
  const GeneralScheduleSlotLaneCard({
    super.key,
    required this.slotIndex,
    required this.cell,
    required this.onTap,
    this.searchQuery = '',
    this.compact = false,
  });

  final int slotIndex;
  final GeneralScheduleCell? cell;
  final VoidCallback onTap;
  final String searchQuery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = cell == null;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final isSearchMismatch = !isEmpty &&
        normalizedQuery.isNotEmpty &&
        !_generalScheduleCellMatchesQuery(cell!, normalizedQuery);
    final accent = isEmpty
        ? scheme.outline
        : (parseGeneralScheduleUserColor(
            cell!.userColor,
            fallback: scheme.primary,
          )!);
    final assignee = isEmpty ? '' : generalScheduleAssigneeLabel(cell!);

    final radius = compact ? 8.0 : 12.0;
    final badgeW = compact ? 36.0 : 52.0;
    final numSize = compact ? 17.0 : 22.0;

    return Material(
      color: isEmpty
          ? scheme.surface
          : isSearchMismatch
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: isEmpty
              ? scheme.outlineVariant
              : accent.withValues(alpha: 0.5),
          width: isEmpty ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox.expand(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.transparent : accent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(radius),
                  ),
                ),
              ),
              SizedBox(
                width: badgeW - 4,
                child: Center(
                  child: Text(
                    '${slotIndex + 1}',
                    style: TextStyle(
                      fontSize: numSize,
                      fontWeight: FontWeight.w800,
                      color: isEmpty ? scheme.onSurfaceVariant : accent,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    compact ? 4 : 10,
                    4,
                    compact ? 4 : 10,
                  ),
                  child: isEmpty
                      ? Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: scheme.primary,
                              size: compact ? 18 : 28,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                compact ? '탭하여 등록' : '빈 칸 — 기간·도어 등록',
                                style: TextStyle(
                                  fontSize: compact ? 12 : 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : compact
                          ? _buildCompactFilled(
                              context,
                              scheme,
                              accent,
                              assignee,
                              isSearchMismatch,
                            )
                          : _buildFullFilled(context, scheme),
                ),
              ),
              if (!isEmpty && !compact)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFilled(
    BuildContext context,
    ColorScheme scheme,
    Color accent,
    String assignee,
    bool isSearchMismatch,
  ) {
    final doorLabel = formatGeneralScheduleDoorSummary(cell!);
    final dayCount = inclusiveDayCount(cell!.start, cell!.endDate);
    final periodLabel =
        '${formatWeekRangeFlowLabel(cell!.start, cell!.endDate)} ($dayCount일)';
    final secondary = [
      if (doorLabel.isNotEmpty) doorLabel,
      periodLabel,
    ].join(' · ');

    if (isSearchMismatch) {
      return Text(
        '검색어와 일치하지 않음',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: scheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                assignee,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GeneralScheduleAutoScrollText(
                text: cell!.site,
                scrollMsPerPixel: 100,
                pauseMs: 1400,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (secondary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              secondary,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildFullFilled(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          cell!.site,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Builder(
          builder: (context) {
            final doorLabel = formatGeneralScheduleDoorSummary(cell!);
            final periodLabel = formatGeneralSchedulePeriodLabel(
              startYmd: cell!.start,
              endYmd: cell!.endDate,
            );
            final meta = [
              if (periodLabel.isNotEmpty)
                periodLabel
              else
                '${cell!.start} ~ ${cell!.endDate}',
              generalScheduleAssigneeLabel(cell!),
            ].where((s) => s.isNotEmpty).join(' · ');
            final subtitle = [
              if (doorLabel.isNotEmpty) doorLabel,
              if (meta.isNotEmpty) meta,
            ].join(' · ');
            if (subtitle.isEmpty) return const SizedBox.shrink();
            return Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: doorLabel.isNotEmpty
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight:
                        doorLabel.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 11,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }
}

bool _generalScheduleCellMatchesQuery(GeneralScheduleCell cell, String query) {
  if (query.isEmpty) return true;
  final haystack = [
    cell.site,
    cell.userName ?? '',
    cell.start,
    cell.endDate,
    ...cell.doorTypes,
    ...cell.models.map((m) => m.name),
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}

bool _isDayFullForAssignee(
  GeneralScheduleDayGrid grid,
  String ymd,
  String assignee,
) {
  final slots = normalizeGeneralScheduleDaySlots(grid[ymd]);
  var matched = 0;
  for (final cell in slots) {
    if (cell == null) continue;
    if (generalScheduleAssigneeLabel(cell) == assignee) {
      matched++;
    }
  }
  return matched >= kGeneralScheduleSlotsPerDay;
}

/// 담당자 필터 + 주간 날짜 스트립 + 선택일 리스트를 하나의 패널로 통합.
class GeneralScheduleWeekPanel extends StatefulWidget {
  const GeneralScheduleWeekPanel({
    super.key,
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.assignees,
    required this.assigneeCounts,
    required this.selectedAssignee,
    required this.colorForAssignee,
    required this.searchQuery,
    required this.onAssigneeChanged,
    required this.onDaySelected,
    required this.onSlotTap,
    required this.onRefresh,
    this.loginUserName,
    this.showAssigneeFilter = true,
  });

  static const totalDays = 121;
  static const centerIndex = 60;

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final List<String> assignees;
  final Map<String, int> assigneeCounts;
  final String selectedAssignee;
  final Color Function(String) colorForAssignee;
  final String searchQuery;
  final ValueChanged<String> onAssigneeChanged;
  final ValueChanged<String> onDaySelected;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;
  final Future<void> Function() onRefresh;
  final String? loginUserName;
  final bool showAssigneeFilter;

  @override
  State<GeneralScheduleWeekPanel> createState() =>
      GeneralScheduleWeekPanelState();
}

class GeneralScheduleWeekPanelState extends State<GeneralScheduleWeekPanel> {
  final _stripKey = GlobalKey<_WeekDateStripState>();

  void scrollStripToCenter() {
    _stripKey.currentState?.scrollToCenter();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dayStats = computeDayStats(widget.grid, widget.selectedYmd);
    final slots = normalizeGeneralScheduleDaySlots(widget.grid[widget.selectedYmd]);
    final filteredUsed = widget.selectedAssignee == kGeneralScheduleAllAssignees
        ? dayStats.usedSlots
        : slots
            .where(
              (c) =>
                  c != null &&
                  generalScheduleAssigneeLabel(c) == widget.selectedAssignee,
            )
            .length;
    final slotSummary = widget.selectedAssignee == kGeneralScheduleAllAssignees
        ? (dayStats.emptySlots == 0
            ? '6/6 만석'
            : '${dayStats.usedSlots}/${dayStats.totalSlots}칸 · 남은 ${dayStats.emptySlots}')
        : '$filteredUsed건';
    final weekdayColor =
        generalScheduleWeekdayColor(DateTime.parse(widget.selectedYmd).weekday);
    final dayLabel = formatYmdFlowLabelKo(widget.selectedYmd);
    final isSelectedToday = widget.selectedYmd == todayYmdSeoul();
    final isFullDay = widget.selectedAssignee == kGeneralScheduleAllAssignees
        ? dayStats.emptySlots == 0
        : filteredUsed >= kGeneralScheduleSlotsPerDay;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showAssigneeFilter) ...[
              const SizedBox(height: 8),
              GeneralScheduleAssigneeFilterBar(
                assignees: widget.assignees,
                counts: widget.assigneeCounts,
                selected: widget.selectedAssignee,
                colorForAssignee: widget.colorForAssignee,
                horizontalPadding: 10,
                onSelected: widget.onAssigneeChanged,
              ),
              const SizedBox(height: 6),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ] else
              const SizedBox(height: 8),
            _WeekDateStrip(
              key: _stripKey,
              days: widget.days,
              selectedYmd: widget.selectedYmd,
              grid: widget.grid,
              assigneeFilter: widget.selectedAssignee,
              onTap: widget.onDaySelected,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  if (isSelectedToday)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '오늘',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      '$dayLabel · $slotSummary'
                      '${widget.searchQuery.isEmpty ? '' : ' · 검색: ${widget.searchQuery}'}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isFullDay
                                ? scheme.error
                                : weekdayColor ?? scheme.onSurface,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.selectedAssignee != kGeneralScheduleAllAssignees)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget
                            .colorForAssignee(widget.selectedAssignee)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.selectedAssignee,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: widget.colorForAssignee(
                            widget.selectedAssignee,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Expanded(
              child: _WeekDaySlotsPager(
                days: widget.days,
                selectedYmd: widget.selectedYmd,
                grid: widget.grid,
                searchQuery: widget.searchQuery,
                assigneeFilter: widget.selectedAssignee,
                loginUserName: widget.loginUserName,
                scheme: scheme,
                onRefresh: widget.onRefresh,
                onDayChanged: widget.onDaySelected,
                onSlotTap: widget.onSlotTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDateStrip extends StatefulWidget {
  const _WeekDateStrip({
    super.key,
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.assigneeFilter,
    required this.onTap,
  });

  static const itemWidth = 56.0;
  static const stripHeight = 64.0;

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final String assigneeFilter;
  final ValueChanged<String> onTap;

  @override
  State<_WeekDateStrip> createState() => _WeekDateStripState();
}

class _WeekDateStripState extends State<_WeekDateStrip> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToCenter());
  }

  @override
  void didUpdateWidget(covariant _WeekDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYmd != widget.selectedYmd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToCenter());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void scrollToCenter() {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final max = _controller.position.maxScrollExtent;
    final target =
        (GeneralScheduleWeekPanel.centerIndex * _WeekDateStrip.itemWidth -
                (viewport - _WeekDateStrip.itemWidth) / 2)
            .clamp(0.0, max);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return ColoredBox(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
      child: SizedBox(
        height: _WeekDateStrip.stripHeight,
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          itemCount: widget.days.length,
          itemBuilder: (context, i) {
            final ymd = widget.days[i];
            final parts = ymd.split('-');
            final dayNum =
                parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
            final isSelected = ymd == widget.selectedYmd;
            final isToday = ymd == todayYmdSeoul();
            final isFull = widget.assigneeFilter == kGeneralScheduleAllAssignees
                ? isGeneralScheduleDayFull(widget.grid, ymd)
                : _isDayFullForAssignee(
                    widget.grid,
                    ymd,
                    widget.assigneeFilter,
                  );
            final slots = normalizeGeneralScheduleDaySlots(widget.grid[ymd]);
            final weekday = DateTime.parse(ymd).weekday;
            final weekendColor = generalScheduleWeekdayColor(weekday);

            return SizedBox(
              width: _WeekDateStrip.itemWidth,
              height: _WeekDateStrip.stripHeight - 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  clipBehavior: Clip.antiAlias,
                  color: isSelected
                      ? scheme.primary
                      : isFull
                          ? scheme.errorContainer.withValues(alpha: 0.55)
                          : isToday
                              ? scheme.primaryContainer
                              : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isSelected
                        ? BorderSide.none
                        : isToday
                            ? BorderSide(color: scheme.primary, width: 2)
                            : isFull
                                ? BorderSide(
                                    color: scheme.error.withValues(alpha: 0.7),
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.onTap(ymd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekdays[weekday - 1],
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : isToday
                                      ? scheme.primary
                                      : (weekendColor ??
                                          scheme.onSurfaceVariant),
                            ),
                          ),
                          if (isToday && !isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.0,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            )
                          else
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? scheme.onPrimary
                                    : (weekendColor ?? scheme.onSurface),
                              ),
                            ),
                          const SizedBox(height: 3),
                          GeneralScheduleStripSlotDots(
                            slots: slots,
                            scheme: scheme,
                            assigneeFilter: widget.assigneeFilter,
                            onPrimary: isSelected,
                          ),
                          if (isFull)
                            Text(
                              '만석',
                              style: TextStyle(
                                fontSize: 7,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? scheme.onPrimary
                                    : scheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WeekDaySlotsPager extends StatefulWidget {
  const _WeekDaySlotsPager({
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.searchQuery,
    required this.assigneeFilter,
    required this.scheme,
    required this.onRefresh,
    required this.onDayChanged,
    required this.onSlotTap,
    this.loginUserName,
  });

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final String searchQuery;
  final String assigneeFilter;
  final ColorScheme scheme;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onDayChanged;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;
  final String? loginUserName;

  @override
  State<_WeekDaySlotsPager> createState() => _WeekDaySlotsPagerState();
}

class _WeekDaySlotsPagerState extends State<_WeekDaySlotsPager> {
  late final PageController _controller;
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: GeneralScheduleWeekPanel.centerIndex,
    );
  }

  @override
  void didUpdateWidget(covariant _WeekDaySlotsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYmd != widget.selectedYmd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSelectedDay());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToSelectedDay() {
    if (!_controller.hasClients) return;
    _programmaticPage = true;
    _controller.jumpToPage(GeneralScheduleWeekPanel.centerIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _programmaticPage = false;
    });
  }

  void _onPageChanged(int index) {
    if (_programmaticPage || index < 0 || index >= widget.days.length) return;
    final ymd = widget.days[index];
    if (ymd == widget.selectedYmd) return;
    widget.onDayChanged(ymd);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.days.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, pageIndex) {
        final ymd = widget.days[pageIndex];
        final daySlots = normalizeGeneralScheduleDaySlots(widget.grid[ymd]);
        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
            children: [
              GeneralScheduleHorizontalSlotRow(
                slots: daySlots,
                scheme: widget.scheme,
                assigneeFilter: widget.assigneeFilter,
                height: 36,
                onSlotTap: (slotIndex, cell) =>
                    widget.onSlotTap(slotIndex, ymd, cell),
              ),
              const SizedBox(height: 8),
              GeneralScheduleAssigneeGroupedDayList(
                daySlots: daySlots,
                searchQuery: widget.searchQuery,
                assigneeFilter: widget.assigneeFilter,
                loginUserName: widget.loginUserName,
                slotHeight: 72,
                onSlotTap: (slotIndex, cell) =>
                    widget.onSlotTap(slotIndex, ymd, cell),
              ),
            ],
          ),
        );
      },
    );
  }
}
