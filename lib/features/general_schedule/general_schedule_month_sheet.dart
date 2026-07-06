import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_calendar_ui.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// 월간 달력 — 메인 화면 인라인·시트 공용.
class GeneralScheduleMonthCalendar extends StatefulWidget {
  const GeneralScheduleMonthCalendar({
    super.key,
    required this.grid,
    required this.focusedMonth,
    required this.assigneeFilter,
    required this.onPickDay,
    this.onFocusedMonthChanged,
    this.loginUserName,
    this.scrollController,
    this.showHeader = false,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 16),
  });

  final GeneralScheduleDayGrid grid;
  final DateTime focusedMonth;
  final String assigneeFilter;
  final ValueChanged<DateTime> onPickDay;
  final ValueChanged<DateTime>? onFocusedMonthChanged;
  final String? loginUserName;
  final ScrollController? scrollController;
  final bool showHeader;
  final EdgeInsets padding;

  @override
  State<GeneralScheduleMonthCalendar> createState() =>
      _GeneralScheduleMonthCalendarState();
}

class _GeneralScheduleMonthCalendarState
    extends State<GeneralScheduleMonthCalendar> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(
      widget.focusedMonth.year,
      widget.focusedMonth.month,
      1,
    );
  }

  @override
  void didUpdateWidget(covariant GeneralScheduleMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedMonth.year != widget.focusedMonth.year ||
        oldWidget.focusedMonth.month != widget.focusedMonth.month) {
      _focusedMonth = DateTime(
        widget.focusedMonth.year,
        widget.focusedMonth.month,
        1,
      );
    }
  }

  String _ymd(DateTime d) => ymdSeoulFromDateTime(d);

  bool _isToday(DateTime day) => _ymd(day) == todayYmdSeoul();

  void _goToTodayMonth() {
    final today = DateTime.parse(todayYmdSeoul());
    setState(() {
      _focusedMonth = DateTime(today.year, today.month, 1);
    });
    widget.onFocusedMonthChanged?.call(_focusedMonth);
    widget.onPickDay(today);
  }

  void _onMonthPageChanged(DateTime focused) {
    setState(() => _focusedMonth = focused);
    widget.onFocusedMonthChanged?.call(focused);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = computeMonthStats(
      widget.grid,
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final today = DateTime.parse(todayYmdSeoul());
    final isCurrentMonth =
        _focusedMonth.year == today.year && _focusedMonth.month == today.month;

    return ListView(
      controller: widget.scrollController,
      padding: widget.padding,
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatGeneralScheduleMonthTitle(stats.year, stats.month),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _goToTodayMonth,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: isCurrentMonth ? scheme.primary : null,
                  ),
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text('오늘'),
                ),
              ],
            ),
          ),
        ],
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
            rowHeight: MediaQuery.orientationOf(context) == Orientation.landscape
                ? 84
                : 152,
            daysOfWeekHeight: 28,
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
            onPageChanged: _onMonthPageChanged,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              isTodayHighlighted: true,
              defaultTextStyle: const TextStyle(fontSize: 0),
              weekendTextStyle: const TextStyle(fontSize: 0),
              todayTextStyle: const TextStyle(fontSize: 0),
              todayDecoration: const BoxDecoration(),
              cellMargin: EdgeInsets.zero,
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                final wd = day.weekday;
                final label =
                    const ['월', '화', '수', '목', '금', '토', '일'][wd - 1];
                final color =
                    generalScheduleWeekdayColor(wd) ?? scheme.onSurfaceVariant;
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
              prioritizedBuilder: (context, day, _) =>
                  _buildMonthDayCell(context, day),
              todayBuilder: (context, day, _) =>
                  _buildMonthDayCell(context, day),
              defaultBuilder: (context, day, _) =>
                  _buildMonthDayCell(context, day),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '날짜 탭 → 해당일 주간 보기 · 만석은 빨간 테두리',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        GeneralScheduleCollapsibleMonthStats(
          stats: stats,
          margin: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildMonthDayCell(BuildContext context, DateTime day) {
    return _monthDayCell(
      context: context,
      day: day,
      grid: widget.grid,
      assigneeFilter: widget.assigneeFilter,
      onTap: () => widget.onPickDay(day),
    );
  }

  Widget _monthDayCell({
    required BuildContext context,
    required DateTime day,
    required GeneralScheduleDayGrid grid,
    required VoidCallback onTap,
    required String assigneeFilter,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final ymd = _ymd(day);
    final isToday = _isToday(day);
    final slots = normalizeGeneralScheduleDaySlots(grid[ymd]);
    final used = assigneeFilter == kGeneralScheduleAllAssignees
        ? occupiedSlotCount(grid, ymd)
        : slots
            .where(
              (c) =>
                  c != null &&
                  generalScheduleAssigneeLabel(c) == assigneeFilter,
            )
            .length;
    final isFull = used >= kGeneralScheduleSlotsPerDay;
    final weekendColor = generalScheduleWeekdayColor(day.weekday);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.fromLTRB(2, 1, 2, 1),
        decoration: BoxDecoration(
          color: isFull
              ? scheme.errorContainer.withValues(alpha: 0.45)
              : (isToday ? scheme.primaryContainer : null),
          border: isFull
              ? Border.all(
                  color: isToday
                      ? scheme.primary
                      : scheme.error.withValues(alpha: 0.75),
                  width: isToday ? 2 : 1.5,
                )
              : isToday
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 13,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimary,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.0,
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
                        fontSize: 7,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ClipRect(
                child: _monthDaySiteContent(
                  context: context,
                  slots: slots,
                  scheme: scheme,
                  assigneeFilter: assigneeFilter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthDaySiteContent({
    required BuildContext context,
    required List<GeneralScheduleCell?> slots,
    required ColorScheme scheme,
    required String assigneeFilter,
  }) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final wide = MediaQuery.sizeOf(context).width >= 680;

    if (landscape || wide) {
      return GeneralScheduleHorizontalSlotRow(
        slots: slots,
        scheme: scheme,
        assigneeFilter: assigneeFilter,
        compact: true,
        height: 32,
        slotGap: 3.5,
      );
    }

    return GeneralScheduleMonthCellSiteList(
      slots: slots,
      scheme: scheme,
      assigneeFilter: assigneeFilter,
      siteFontSize: 8.0,
      siteRowHeight: 14,
      siteRowGap: 1,
    );
  }
}

/// 월간 달력 바텀시트.
class GeneralScheduleMonthSheet extends StatelessWidget {
  const GeneralScheduleMonthSheet({
    super.key,
    required this.grid,
    required this.initialMonth,
    required this.onPickDay,
    this.assigneeFilter = kGeneralScheduleAllAssignees,
    this.loginUserName,
  });

  final GeneralScheduleDayGrid grid;
  final DateTime initialMonth;
  final ValueChanged<DateTime> onPickDay;
  final String assigneeFilter;
  final String? loginUserName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
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
              Expanded(
                child: GeneralScheduleMonthCalendar(
                  grid: grid,
                  focusedMonth: initialMonth,
                  assigneeFilter: assigneeFilter,
                  loginUserName: loginUserName,
                  scrollController: scrollController,
                  showHeader: true,
                  onPickDay: (day) {
                    Navigator.pop(context);
                    onPickDay(day);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 메인 화면용 컴팩트 통계 바 (레거시 — [GeneralScheduleCollapsibleMonthStats] 권장).
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
