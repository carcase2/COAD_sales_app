import 'package:coad_customer_calls/features/work/work_assignee_style.dart';
import 'package:coad_customer_calls/features/work/work_calendar.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// 업무 한 줄. 왼쪽 동그라미가 완료 여부다.
///
/// - 빈 동그라미 + 「완료하기」: 아직 할 일 — 누르면 완료 처리.
/// - 초록 체크 + 「완료됨」: 끝난 일 — 누르면 다시 연다.
class WorkTaskCard extends StatelessWidget {
  const WorkTaskCard({
    super.key,
    required this.task,
    required this.today,
    required this.busy,
    required this.assigneeColors,
    this.onOpen,
    this.onStart,
    this.onComplete,
    this.onReopen,
  });

  final WorkTask task;
  final String today;
  final bool busy;
  final Map<String, Color> assigneeColors;
  final VoidCallback? onOpen;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = task.isDone;
    final group = workTaskGroup(task.dueDate, today);
    final urgent = !done && task.priorityName == '특급';
    final overdue = !done && !task.isHeld && group == WorkTaskGroup.overdue;
    final stripe = workTaskAssigneeColors(task, assigneeColors);
    final people = visibleTaskAssignees(
      task,
    ).map((person) => person.name).join(', ');
    final requester = task.requester.trim();
    final who = [
      if (people.isNotEmpty) '담당 $people',
      if (requester.isNotEmpty) '요청 $requester',
    ].join(' · ');
    final border = urgent || overdue
        ? scheme.error
        : group == WorkTaskGroup.today && !done
        ? scheme.primary
        : scheme.outlineVariant;

    return Material(
      color: done
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : urgent
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(
          color: border,
          width: border == scheme.outlineVariant ? 1 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 6,
                child: Column(
                  children: [
                    for (final color in stripe)
                      Expanded(
                        child: ColoredBox(
                          color: done ? color.withValues(alpha: 0.4) : color,
                        ),
                      ),
                  ],
                ),
              ),
              _DoneToggle(
                done: done,
                onTap: busy ? null : (done ? onReopen : onComplete),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: done ? scheme.onSurfaceVariant : null,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          WorkStatusBadge(task: task),
                          _DueBadge(task: task, today: today),
                          if (!done &&
                              (task.priorityName == '특급' ||
                                  task.priorityName == '높음'))
                            WorkPriorityPill(
                              name: task.priorityName,
                              small: true,
                            ),
                        ],
                      ),
                      if (who.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onStart != null && task.status == '접수')
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: busy ? null : onStart,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(52, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('시작'),
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

/// 왼쪽 완료 동그라미. 글자로도 지금 상태를 같이 적는다.
class _DoneToggle extends StatelessWidget {
  const _DoneToggle({required this.done, required this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final green = workDoneColor(scheme);
    return Tooltip(
      message: done ? '다시 열기' : '완료 처리',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 30,
                color: done
                    ? green
                    : onTap == null
                    ? scheme.outlineVariant
                    : scheme.outline,
              ),
              const SizedBox(height: 2),
              Text(
                done ? '완료됨' : '완료하기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: done ? green : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color workDoneColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFF6BD08F)
    : const Color(0xFF1E8E4E);

Color workHeldColor(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFFF2B95C)
    : const Color(0xFFB26A00);

/// 지금 상태 — 할 일 · 진행중 · 보류 · 완료.
class WorkStatusBadge extends StatelessWidget {
  const WorkStatusBadge({super.key, required this.task});

  final WorkTask task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color, icon) = switch (task.status) {
      '진행중' => ('진행중', scheme.primary, Icons.play_arrow_rounded),
      '보류' => ('보류', workHeldColor(scheme), Icons.pause_rounded),
      '완료' => (
        task.completedDate.length >= 10
            ? '완료 ${_monthDay(task.completedDate)}'
            : '완료',
        workDoneColor(scheme),
        Icons.check_rounded,
      ),
      _ => ('할 일', scheme.onSurfaceVariant, Icons.inbox_outlined),
    };
    return _Badge(label: label, color: color, icon: icon);
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.task, required this.today});

  final WorkTask task;
  final String today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offset = workDueOffset(task.dueDate, today);
    if (offset == null) {
      return _Badge(
        label: '기한 없음',
        color: scheme.onSurfaceVariant,
        icon: Icons.event_busy_outlined,
        outlined: true,
      );
    }
    final date = _monthDay(task.dueDate);
    if (task.isDone) {
      return _Badge(
        label: '기한 $date',
        color: scheme.onSurfaceVariant,
        icon: Icons.event_outlined,
        outlined: true,
      );
    }
    final (label, color, strong) = offset < 0
        ? ('${-offset}일 지남 · $date', scheme.error, true)
        : offset == 0
        ? ('오늘 마감', scheme.primary, true)
        : offset == 1
        ? ('내일 · $date', scheme.onSurface, false)
        : ('$date · D-$offset', scheme.onSurface, false);
    return _Badge(
      label: label,
      color: color,
      icon: Icons.event_outlined,
      outlined: !strong,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? null : color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: outlined ? 0.4 : 0)),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkPriorityPill extends StatelessWidget {
  const WorkPriorityPill({super.key, required this.name, this.small = false});

  final String name;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = name == '후순위'
        ? scheme.surfaceContainerHighest
        : workPriorityColor(scheme, name);
    final foreground = switch (name) {
      '특급' => scheme.onError,
      '높음' => scheme.onTertiary,
      '보통' => scheme.onPrimary,
      '낮음' => scheme.onSecondary,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 7 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: small ? 12 : 13,
        ),
      ),
    );
  }
}

/// 목록 묶음 머리 — 이름, 건수, 색 막대.
class WorkSectionHeader extends StatelessWidget {
  const WorkSectionHeader({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 묶음 색 — 지남 빨강, 오늘 파랑, 나머지 차분하게.
Color workGroupColor(ColorScheme scheme, WorkTaskGroup group) =>
    switch (group) {
      WorkTaskGroup.overdue => scheme.error,
      WorkTaskGroup.today => scheme.primary,
      WorkTaskGroup.week => scheme.tertiary,
      WorkTaskGroup.later => scheme.onSurfaceVariant,
      WorkTaskGroup.undated => scheme.outline,
    };

String _monthDay(String? ymd) {
  if (ymd == null || ymd.length < 10) return ymd ?? '';
  final month = int.tryParse(ymd.substring(5, 7));
  final day = int.tryParse(ymd.substring(8, 10));
  if (month == null || day == null) return ymd;
  return '$month/$day';
}
