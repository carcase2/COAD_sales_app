import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter/material.dart';

Color workPriorityColor(ColorScheme scheme, String name) {
  return switch (name) {
    '특급' => scheme.error,
    '높음' => scheme.tertiary,
    '보통' => scheme.primary,
    '낮음' => scheme.secondary,
    _ => scheme.outline,
  };
}

/// 월간 또는 주간. 업무가 있는 날만 점을 찍고, 누르면 그 날 목록을 연다.
class WorkMonthMarks extends StatelessWidget {
  const WorkMonthMarks({
    super.key,
    required this.week,
    required this.today,
    required this.monthDay,
    required this.tasks,
    required this.onWeekChanged,
    required this.onShift,
    required this.onToday,
    required this.onDay,
  });

  final bool week;
  final String today;
  final String monthDay;
  final List<WorkTask> tasks;
  final ValueChanged<bool> onWeekChanged;
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final ValueChanged<String> onDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focus = monthDay.length >= 10 ? monthDay : today;
    final urgentDays = <String>{};
    final busyDays = <String>{};
    for (final task in tasks) {
      for (final ymd in workTaskMarkDays(task)) {
        busyDays.add(ymd);
        if (!task.isDone && task.priorityName == '특급') urgentDays.add(ymd);
      }
    }
    final weekDays = week ? seoulSundayWeekDays(focus) : const <String>[];
    final cells = week ? <String?>[...weekDays] : workMonthCells(focus);
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    final title = week
        ? formatMonthDayRangeKo(weekDays.first, weekDays.last)
        : _monthTitle(focus);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: week ? '지난주' : '지난달',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: () => onShift(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('오늘'),
            ),
            IconButton(
              tooltip: week ? '다음주' : '다음달',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: () => onShift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SpanChoice(
              label: '월간',
              selected: !week,
              onTap: () => onWeekChanged(false),
            ),
            const SizedBox(width: 6),
            _SpanChoice(
              label: '주간',
              selected: week,
              onTap: () => onWeekChanged(true),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: i == 0 ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        if (week)
          SizedBox(
            height: 84,
            child: Row(
              children: [
                for (final cell in weekDays)
                  Expanded(
                    child: _MarkDay(
                      day: cell.substring(8),
                      today: cell == today,
                      weekend: _weekend(cell),
                      busy: busyDays.contains(cell),
                      urgent: urgentDays.contains(cell),
                      large: true,
                      onTap: () => onDay(cell),
                    ),
                  ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 40,
            ),
            itemBuilder: (context, index) {
              final cell = cells[index];
              if (cell == null) return const SizedBox.shrink();
              return _MarkDay(
                day: cell.substring(8),
                today: cell == today,
                weekend: _weekend(cell),
                busy: busyDays.contains(cell),
                urgent: urgentDays.contains(cell),
                onTap: () => onDay(cell),
              );
            },
          ),
      ],
    );
  }

  String _monthTitle(String focus) {
    final parts = focus.split('-');
    if (parts.length < 2) return focus;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return focus;
    return '$year년 $month월';
  }

  bool _weekend(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return false;
    final day = DateTime(
      int.tryParse(parts[0]) ?? 1,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
    return day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;
  }
}

class _SpanChoice extends StatelessWidget {
  const _SpanChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkDay extends StatelessWidget {
  const _MarkDay({
    required this.day,
    required this.today,
    required this.weekend,
    required this.busy,
    required this.urgent,
    required this.onTap,
    this.large = false,
  });

  final String day;
  final bool today;
  final bool weekend;
  final bool busy;
  final bool urgent;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final number = int.tryParse(day)?.toString() ?? day;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: large ? 18 : null,
              fontWeight: today ? FontWeight.w900 : FontWeight.w700,
              color: today
                  ? scheme.primary
                  : weekend
                  ? scheme.error
                  : scheme.onSurface,
            ),
          ),
          Container(
            width: large ? 8 : 6,
            height: large ? 8 : 6,
            decoration: BoxDecoration(
              color: !busy
                  ? Colors.transparent
                  : urgent
                  ? scheme.error
                  : scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
