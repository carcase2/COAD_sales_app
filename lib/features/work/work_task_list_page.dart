import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/work/work_assignee_style.dart';
import 'package:coad_customer_calls/features/work/work_task_card.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

enum WorkListView { open, held, done }

/// 업무 목록 — 달력과 따로 본다. 남은 일은 기한 묶음, 완료는 끝낸 날 묶음.
class WorkTaskListPage extends StatefulWidget {
  const WorkTaskListPage({
    super.key,
    required this.tick,
    required this.board,
    required this.busy,
    required this.colors,
    required this.card,
    required this.onAdd,
    required this.onRefresh,
    this.initialView = WorkListView.open,
    this.initialScope = WorkTaskScope.all,
    this.initialEmail,
  });

  /// 화면 쪽에서 값이 바뀌면 올라간다.
  final ValueNotifier<int> tick;
  final WorkTaskBoard? Function() board;
  final bool Function() busy;
  final Map<String, Color> Function() colors;
  final Widget Function(WorkTask task) card;
  final void Function(String? assigneeEmail) onAdd;
  final Future<void> Function() onRefresh;
  final WorkListView initialView;
  final WorkTaskScope initialScope;
  final String? initialEmail;

  @override
  State<WorkTaskListPage> createState() => _WorkTaskListPageState();
}

class _WorkTaskListPageState extends State<WorkTaskListPage> {
  late WorkListView _view = widget.initialView;
  late WorkTaskScope _scope = widget.initialScope;
  late String? _email = widget.initialEmail;
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<WorkTask> _rows(WorkTaskBoard board, WorkListView view) {
    final source = switch (view) {
      WorkListView.open => board.remaining,
      WorkListView.held => board.held,
      WorkListView.done => board.recentDone,
    };
    final byPerson = filterWorkTasks(source, assigneeEmail: _email);
    final byScope = scopeWorkTasks(
      byPerson,
      _scope,
      myEmail: board.myEmail,
      myName: board.myName,
    );
    return searchWorkTasks(byScope, _query);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.tick,
      builder: (context, _, _) {
        final board = widget.board();
        return Scaffold(
          appBar: AppBar(title: const Text('업무 목록')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: widget.busy() ? null : () => widget.onAdd(_email),
            icon: const Icon(Icons.add_rounded),
            label: const Text('업무 추가'),
          ),
          body: board == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: _body(context, board),
                ),
        );
      },
    );
  }

  Widget _body(BuildContext context, WorkTaskBoard board) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _rows(board, _view);
    final counts = {
      for (final view in WorkListView.values) view: _rows(board, view).length,
    };
    final people = visibleWorkAssignees(board.assignees);
    final colors = widget.colors();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceLg,
        AppTokens.spaceSm,
        AppTokens.spaceLg,
        96,
      ),
      children: [
        SegmentedButton<WorkListView>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: WorkListView.open,
              label: Text('할 일 ${counts[WorkListView.open]}'),
            ),
            ButtonSegment(
              value: WorkListView.held,
              label: Text('보류 ${counts[WorkListView.held]}'),
            ),
            ButtonSegment(
              value: WorkListView.done,
              label: Text('완료 ${counts[WorkListView.done]}'),
            ),
          ],
          selected: {_view},
          onSelectionChanged: (picked) => setState(() => _view = picked.first),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: '제목·내용·요청·담당 검색',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: '지우기',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final scope in WorkTaskScope.values) ...[
                ChoiceChip(
                  label: Text(switch (scope) {
                    WorkTaskScope.all => '전체',
                    WorkTaskScope.mine => '내 업무',
                    WorkTaskScope.requested => '내가 요청',
                  }),
                  selected: _scope == scope,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _scope = scope),
                ),
                const SizedBox(width: 6),
              ],
              const VerticalDivider(width: 12),
              for (final person in people) ...[
                FilterChip(
                  label: Text(person.name),
                  selected: _email == person.email,
                  visualDensity: VisualDensity.compact,
                  avatar: CircleAvatar(
                    radius: 5,
                    backgroundColor: workAssigneeColor(person.email, colors),
                  ),
                  onSelected: (on) =>
                      setState(() => _email = on ? person.email : null),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              _emptyLabel(),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else
          ..._grouped(context, board, rows),
      ],
    );
  }

  List<Widget> _grouped(
    BuildContext context,
    WorkTaskBoard board,
    List<WorkTask> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (_view) {
      case WorkListView.open:
        return [
          for (final section in workTaskSections(rows, board.today)) ...[
            WorkSectionHeader(
              label: section.label,
              count: section.tasks.length,
              color: workGroupColor(scheme, section.group),
            ),
            for (final task in section.tasks) ...[
              widget.card(task),
              const SizedBox(height: 8),
            ],
          ],
        ];
      case WorkListView.held:
        return [
          WorkSectionHeader(
            label: '보류 중',
            count: rows.length,
            color: workHeldColor(scheme),
          ),
          for (final task in rows) ...[
            widget.card(task),
            const SizedBox(height: 8),
          ],
        ];
      case WorkListView.done:
        final byDay = <String, List<WorkTask>>{};
        for (final task in rows) {
          (byDay[task.completedDate] ??= []).add(task);
        }
        return [
          for (final entry in byDay.entries) ...[
            WorkSectionHeader(
              label: _doneLabel(entry.key, board.today),
              count: entry.value.length,
              color: workDoneColor(scheme),
            ),
            for (final task in entry.value) ...[
              widget.card(task),
              const SizedBox(height: 8),
            ],
          ],
        ];
    }
  }

  String _doneLabel(String ymd, String today) {
    if (ymd.length < 10) return '완료일 모름';
    final offset = workDueOffset(ymd, today);
    if (offset == 0) return '오늘 완료';
    if (offset == -1) return '어제 완료';
    return '${formatYmdFlowLabelKo(ymd)} 완료';
  }

  String _emptyLabel() {
    if (_query.trim().isNotEmpty) return '「${_query.trim()}」 업무가 없습니다.';
    return switch (_view) {
      WorkListView.open => switch (_scope) {
        WorkTaskScope.mine => '내가 맡은 할 일이 없습니다.',
        WorkTaskScope.requested => '내가 요청한 할 일이 없습니다.',
        WorkTaskScope.all => '남은 할 일이 없습니다.',
      },
      WorkListView.held => '보류한 업무가 없습니다.',
      WorkListView.done => '최근 2주 완료한 업무가 없습니다.',
    };
  }
}
