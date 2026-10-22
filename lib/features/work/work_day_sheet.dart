import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// 날짜를 누르면 예정·완료를 고르고, 고른 뒤에 그 목록을 연다.
class WorkDaySheet extends StatefulWidget {
  const WorkDaySheet({
    super.key,
    required this.ymd,
    required this.tasks,
    required this.taskBuilder,
    required this.onAdd,
    this.busy = false,
  });

  final String ymd;
  final List<WorkTask> tasks;
  final Widget Function(WorkTask task) taskBuilder;
  final VoidCallback onAdd;
  final bool busy;

  @override
  State<WorkDaySheet> createState() => _WorkDaySheetState();
}

enum _DayListKind { planned, done }

class _WorkDaySheetState extends State<WorkDaySheet> {
  _DayListKind? _kind;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final kind = _kind;
    return SizedBox(
      height: height,
      child: kind == null ? _menu(context) : _list(context, kind),
    );
  }

  Widget _menu(BuildContext context) {
    final planned = workTasksForDay(widget.tasks, widget.ymd, completed: false);
    final done = workTasksForDay(widget.tasks, widget.ymd, completed: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLg),
          child: Text(
            formatYmdFlowLabelKo(widget.ymd),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: AppTokens.spaceLg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLg),
          child: Column(
            children: [
              _choice(
                context,
                label: '예정',
                hint: '아직 끝나지 않은 업무',
                count: planned.length,
                icon: Icons.event_note_rounded,
                onTap: () => setState(() => _kind = _DayListKind.planned),
              ),
              const SizedBox(height: 10),
              _choice(
                context,
                label: '완료',
                hint: '이 날 끝낸 업무',
                count: done.length,
                icon: Icons.task_alt_rounded,
                onTap: () => setState(() => _kind = _DayListKind.done),
              ),
            ],
          ),
        ),
        const Spacer(),
        _addButton(),
      ],
    );
  }

  Widget _choice(
    BuildContext context, {
    required String label,
    required String hint,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTokens.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        hint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$count건',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, _DayListKind kind) {
    final completed = kind == _DayListKind.done;
    final tasks = workTasksForDay(
      widget.tasks,
      widget.ymd,
      completed: completed,
    );
    final title = completed ? '완료' : '예정';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppTokens.spaceLg),
          child: Row(
            children: [
              IconButton(
                tooltip: '메뉴',
                onPressed: () => setState(() => _kind = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  '${formatYmdFlowLabelKo(widget.ymd)} · $title',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(completed ? '완료한 업무가 없습니다.' : '예정된 업무가 없습니다.'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.spaceLg,
                    0,
                    AppTokens.spaceLg,
                    AppTokens.spaceSm,
                  ),
                  children: [
                    for (final task in tasks) ...[
                      widget.taskBuilder(task),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        if (!completed) _addButton(),
      ],
    );
  }

  Widget _addButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceSm,
          AppTokens.spaceLg,
          AppTokens.spaceMd,
        ),
        child: FilledButton(
          onPressed: widget.busy ? null : widget.onAdd,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
          ),
          child: const Text('이 날 업무 추가'),
        ),
      ),
    );
  }
}
