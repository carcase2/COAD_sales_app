import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// 월간 달력 + 통계 — 날짜 탭 시 [onPickDay]로 메인 화면에 반영.
class GeneralScheduleMonthSheet extends StatefulWidget {
  const GeneralScheduleMonthSheet({
    super.key,
    required this.grid,
    required this.initialMonth,
    required this.onPickDay,
  });

  final GeneralScheduleDayGrid grid;
  final DateTime initialMonth;
  final ValueChanged<DateTime> onPickDay;

  @override
  State<GeneralScheduleMonthSheet> createState() =>
      _GeneralScheduleMonthSheetState();
}

class _GeneralScheduleMonthSheetState extends State<GeneralScheduleMonthSheet> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
  }

  String _ymd(DateTime d) => ymdSeoulFromDateTime(d);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = computeMonthStats(
      widget.grid,
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final occupancyPct = (stats.occupancyRate * 100).round();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
              Text(
                formatGeneralScheduleMonthTitle(stats.year, stats.month),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              _MonthStatsPanel(stats: stats, occupancyPct: occupancyPct),
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: TableCalendar<void>(
                  locale: 'ko_KR',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedMonth,
                  calendarFormat: CalendarFormat.month,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  rowHeight: 52,
                  daysOfWeekHeight: 32,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                    weekendStyle: const TextStyle(fontSize: 0),
                  ),
                  onPageChanged: (focused) =>
                      setState(() => _focusedMonth = focused),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(fontSize: 0),
                    weekendTextStyle: const TextStyle(fontSize: 0),
                    todayTextStyle: const TextStyle(fontSize: 0),
                    cellMargin: EdgeInsets.zero,
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final wd = day.weekday;
                      final label = const ['월', '화', '수', '목', '금', '토', '일']
                          [wd - 1];
                      final color = generalScheduleWeekdayColor(wd) ??
                          scheme.onSurfaceVariant;
                      return Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, _) => _monthDayCell(
                      context: context,
                      day: day,
                      grid: widget.grid,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPickDay(day);
                      },
                    ),
                    todayBuilder: (context, day, _) => _monthDayCell(
                      context: context,
                      day: day,
                      grid: widget.grid,
                      isToday: true,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPickDay(day);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '날짜 탭 → 일정 등록 (만석·빨간 테두리는 6/6)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _monthDayCell({
    required BuildContext context,
    required DateTime day,
    required GeneralScheduleDayGrid grid,
    required VoidCallback onTap,
    bool isToday = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ymd = _ymd(day);
    final slots = grid[ymd] ?? emptyDaySlots();
    final used = occupiedSlotCount(grid, ymd);
    final isFull = used >= kGeneralScheduleSlotsPerDay;
    final weekendColor = generalScheduleWeekdayColor(day.weekday);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
        decoration: BoxDecoration(
          color: isFull
              ? scheme.errorContainer.withValues(alpha: 0.45)
              : (isToday ? scheme.primaryContainer : null),
          border: isFull
              ? Border.all(color: scheme.error.withValues(alpha: 0.75), width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isFull
                        ? scheme.error
                        : (weekendColor ?? scheme.onSurface),
                  ),
                ),
                if (isFull) ...[
                  const SizedBox(width: 2),
                  Text(
                    '만',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: scheme.error,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
                final filled = slots[i] != null;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(
                      right: i < kGeneralScheduleSlotsPerDay - 1 ? 1 : 0,
                    ),
                    color: filled
                        ? (parseGeneralScheduleUserColor(
                              slots[i]!.userColor,
                              fallback: scheme.primary,
                            ))
                        : scheme.surfaceContainerHighest,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthStatsPanel extends StatelessWidget {
  const _MonthStatsPanel({
    required this.stats,
    required this.occupancyPct,
  });

  final GeneralScheduleMonthStats stats;
  final int occupancyPct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '월간 통계',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: '전체 칸',
                    value: '${stats.totalSlots}',
                    sub: '${stats.daysInMonth}일×$kGeneralScheduleSlotsPerDay',
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: '사용',
                    value: '${stats.usedSlots}',
                    sub: '$occupancyPct%',
                    color: scheme.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: '남음',
                    value: '${stats.emptySlots}',
                    sub: stats.emptySlots == 0 ? '만석' : '여유',
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
              const SizedBox(height: 12),
              Text(
                '담당자별 칸 수',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              ...stats.byUser.take(8).map((u) {
                final accent = parseGeneralScheduleUserColor(
                  u.color,
                  fallback: scheme.primary,
                )!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          u.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                      Text(
                        '${u.count}칸',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            sub,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// 메인 화면용 컴팩트 통계 바.
class GeneralScheduleStatsBar extends StatelessWidget {
  const GeneralScheduleStatsBar({
    super.key,
    required this.dayStats,
    required this.monthStats,
    this.onOpenMonth,
    this.compact = false,
  });

  final GeneralScheduleDayStats dayStats;
  final GeneralScheduleMonthStats monthStats;
  final VoidCallback? onOpenMonth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthPct = (monthStats.occupancyRate * 100).round();

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 8, 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatGeneralScheduleMonthTitle(monthStats.year, monthStats.month)} '
                    '${monthStats.usedSlots}/${monthStats.totalSlots} · '
                    '남은 ${monthStats.emptySlots} ($monthPct%)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: monthStats.occupancyRate.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            if (onOpenMonth != null)
              TextButton(
                onPressed: onOpenMonth,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('월간'),
              ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '선택일 ${dayStats.usedSlots}/${dayStats.totalSlots}칸 · '
                    '남은 ${dayStats.emptySlots}칸',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onOpenMonth != null)
                  TextButton(
                    onPressed: onOpenMonth,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('월간'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${formatGeneralScheduleMonthTitle(monthStats.year, monthStats.month)} '
              '${monthStats.usedSlots}/${monthStats.totalSlots}칸 사용 · '
              '${monthStats.emptySlots}칸 남음 ($monthPct%)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: monthStats.occupancyRate.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}