import 'dart:async';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/work_permissions.dart';
import 'package:coad_customer_calls/data/work_task_repository.dart';
import 'package:coad_customer_calls/features/work/work_assignee_style.dart';
import 'package:coad_customer_calls/features/work/work_calendar.dart';
import 'package:coad_customer_calls/features/work/work_requests_screen.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 남은 업무 목록. 알림을 눌러도 이 화면이 열린다.
class WorkTasksScreen extends ConsumerStatefulWidget {
  const WorkTasksScreen({super.key, this.embedded = false, this.initialTaskId});

  static const routeName = 'WorkTasks';

  /// 홈 업무 탭에서는 상단 제목 줄을 생략한다.
  final bool embedded;

  /// 알림으로 열면 불러온 뒤 이 업무 상세를 바로 연다.
  final String? initialTaskId;

  @override
  ConsumerState<WorkTasksScreen> createState() => _WorkTasksScreenState();
}

class _WorkTasksScreenState extends ConsumerState<WorkTasksScreen> {
  WorkTaskBoard? _board;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  _WorkView _view = _WorkView.open;
  WorkTaskScope _scope = WorkTaskScope.all;
  String _query = '';
  bool _searching = false;
  String? _pendingOpenId;
  final TextEditingController _search = TextEditingController();
  bool _calendarWeek = false;
  String? _assigneeEmail;
  String? _monthAnchor;
  final ValueNotifier<int> _detailTick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _pendingOpenId = widget.initialTaskId;
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant WorkTasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTaskId != null &&
        widget.initialTaskId != oldWidget.initialTaskId) {
      _pendingOpenId = widget.initialTaskId;
      _openPending();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _detailTick.dispose();
    super.dispose();
  }

  void _touchDetail() {
    _detailTick.value++;
  }

  Future<void> _load() async {
    final user = ref.read(authControllerProvider);
    if (!canAccessWorkTasks(user)) {
      setState(() {
        _loading = false;
        _error = ApiException('연구소와 관리자만 업무를 볼 수 있습니다.');
      });
      _touchDetail();
      return;
    }
    setState(() {
      _loading = _board == null;
      _error = null;
    });
    try {
      final board = await WorkTaskRepository(
        Supabase.instance.client,
      ).load(user!.id);
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
      _touchDetail();
      _openPending();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      _touchDetail();
    }
  }

  /// 알림에서 넘어온 업무 — 목록에 있으면 상세를 연다 (완료된 지 2주 넘으면 없음).
  void _openPending() {
    final id = (_pendingOpenId ?? '').trim();
    if (id.isEmpty || _board == null) return;
    _pendingOpenId = null;
    final task = _taskById(id);
    if (task == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림의 업무를 목록에서 찾지 못했습니다.')));
      return;
    }
    if (task.isHeld) setState(() => _view = _WorkView.held);
    if (task.isDone) setState(() => _view = _WorkView.done);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(task);
    });
  }

  Future<void> _run(
    Future<WorkTaskBoard> future, {
    String? undoLabel,
    String? doneMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    _touchDetail();
    try {
      final board = await future;
      if (!mounted) return;
      setState(() => _board = board);
      _touchDetail();
      final undo = board.undo;
      if (undoLabel != null && undo != null && undo.isValid) {
        _showUndo(undoLabel, undo);
      } else if (doneMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : '처리하지 못했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _touchDetail();
      }
    }
  }

  Future<void> _add({String? dueDate, String? assigneeEmail}) async {
    final board = _board;
    final user = ref.read(authControllerProvider);
    if (board == null || user == null || _busy) return;
    final draft = await showModalBottomSheet<_NewWorkDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddWorkSheet(
        assignees: visibleWorkAssignees(board.assignees),
        priorities: board.priorities,
        today: board.today,
        initialEmails: [?(assigneeEmail ?? board.myEmail)],
        initialDue: dueDate ?? _addDue(board),
        initialPriorityId: _priorityIdFor(board),
      ),
    );
    if (draft == null || !mounted) return;
    await _run(
      WorkTaskRepository(Supabase.instance.client).create(
        userId: user.id,
        title: draft.title,
        detail: draft.detail,
        assigneeEmails: draft.assigneeEmails,
        dueDate: draft.dueDate,
        priorityId: draft.priorityId,
      ),
      doneMessage: '「${draft.title}」 추가했습니다.',
    );
  }

  String _addDue(WorkTaskBoard board) {
    return board.today;
  }

  String? _priorityIdFor(WorkTaskBoard board) {
    for (final priority in board.priorities) {
      if (priority.name == '보통') return priority.id;
    }
    if (board.priorities.isEmpty) return null;
    return board.priorities.first.id;
  }

  void _shiftFocus(int direction) {
    final base = _monthAnchor ?? _board?.today ?? '';
    if (base.isEmpty) return;
    setState(() {
      _monthAnchor = _calendarWeek
          ? addDaysToYmd(base, direction * 7)
          : shiftWorkMonth(base, direction);
    });
  }

  String? _selectedEmail(WorkTaskBoard board) {
    final email = (_assigneeEmail ?? '').trim();
    if (email.isEmpty) return null;
    for (final person in visibleWorkAssignees(board.assignees)) {
      if (person.email == email) return email;
    }
    return null;
  }

  List<WorkTask> _source(WorkTaskBoard board, _WorkView view) => switch (view) {
    _WorkView.open => board.remaining,
    _WorkView.held => board.held,
    _WorkView.done => board.recentDone,
  };

  /// 보기(남은·보류·완료) → 담당 칩 → 전체/내 업무/내가 요청 → 검색 순으로 거른다.
  List<WorkTask> _filtered(WorkTaskBoard board, _WorkView view) {
    final byPerson = filterWorkTasks(
      _source(board, view),
      assigneeEmail: _selectedEmail(board),
    );
    final byScope = scopeWorkTasks(
      byPerson,
      _scope,
      myEmail: board.myEmail,
      myName: board.myName,
    );
    return searchWorkTasks(byScope, _query);
  }

  List<WorkTask> _scoped(WorkTaskBoard board) => _filtered(board, _view);

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(workTasksRefreshProvider, (previous, next) {
      if (previous != next) _load();
    });
    ref.listen<String?>(workTaskOpenProvider, (previous, next) {
      final id = (next ?? '').trim();
      if (id.isEmpty) return;
      _pendingOpenId = id;
      Future<void>.microtask(() {
        ref.read(workTaskOpenProvider.notifier).state = null;
      });
      // 새로 읽은 뒤 연다 (_load 끝에서 _openPending).
    });
    final board = _board;
    final rows = board == null ? const <WorkTask>[] : _scoped(board);
    final counts = <_WorkView, int>{
      for (final view in _WorkView.values)
        view: board == null ? 0 : _filtered(board, view).length,
    };

    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('업무'),
              actions: [
                TextButton.icon(
                  onPressed: _openRequests,
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  label: const Text('부서 요청'),
                ),
              ],
            ),
      body: Column(
        children: [
          if (board != null)
            _AssigneeBar(
              people: visibleWorkAssignees(board.assignees),
              selectedEmail: _selectedEmail(board),
              colors: _assigneeColors(board),
              busy: _busy,
              onSelected: (email) {
                setState(() => _assigneeEmail = email);
                _touchDetail();
              },
              onAdd: () => _add(assigneeEmail: _selectedEmail(board)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && board == null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppTokens.spaceXl),
                          child: Text(
                            _error is ApiException
                                ? (_error! as ApiException).message
                                : '업무를 불러오지 못했습니다.',
                          ),
                        ),
                      ],
                    )
                  : _workList(board, rows, counts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workList(
    WorkTaskBoard? board,
    List<WorkTask> rows,
    Map<_WorkView, int> counts,
  ) {
    final month = _monthAnchor ?? board?.today ?? '';
    final today = board?.today ?? '';
    final sections = _view == _WorkView.open
        ? workTaskSections(rows, today)
        : const <WorkTaskSection>[];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceLg,
        0,
        AppTokens.spaceLg,
        AppTokens.spaceXl,
      ),
      children: [
        if (board != null && month.isNotEmpty && _view == _WorkView.open)
          WorkMonthMarks(
            week: _calendarWeek,
            today: board.today,
            monthDay: month,
            tasks: rows,
            onWeekChanged: (week) => setState(() => _calendarWeek = week),
            onShift: _shiftFocus,
            onToday: () => setState(() => _monthAnchor = board.today),
            onDay: _openDay,
          ),
        if (board != null) ...[
          const SizedBox(height: AppTokens.spaceSm),
          _listControls(board, counts),
          const SizedBox(height: AppTokens.spaceSm),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXl),
              child: Text(
                _emptyLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (_view == _WorkView.open)
            for (final section in sections) ...[
              _SectionHeader(
                label: section.label,
                count: section.tasks.length,
                alert: section.kind == WorkDueKind.overdue,
              ),
              for (final task in section.tasks) ...[
                _taskCard(task),
                const SizedBox(height: 8),
              ],
            ]
          else
            for (final task in rows) ...[
              _taskCard(task),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }

  String _emptyLabel() {
    if (_query.trim().isNotEmpty) return '「${_query.trim()}」 업무가 없습니다.';
    return switch (_view) {
      _WorkView.open => switch (_scope) {
        WorkTaskScope.mine => '내가 맡은 남은 업무가 없습니다.',
        WorkTaskScope.requested => '내가 요청한 남은 업무가 없습니다.',
        WorkTaskScope.all => '남은 업무가 없습니다.',
      },
      _WorkView.held => '보류한 업무가 없습니다.',
      _WorkView.done => '최근 2주 완료한 업무가 없습니다.',
    };
  }

  Widget _listControls(WorkTaskBoard board, Map<_WorkView, int> counts) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_WorkView>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: _WorkView.open,
                    label: Text('남은 ${counts[_WorkView.open] ?? 0}'),
                  ),
                  ButtonSegment(
                    value: _WorkView.held,
                    label: Text('보류 ${counts[_WorkView.held] ?? 0}'),
                  ),
                  ButtonSegment(
                    value: _WorkView.done,
                    label: Text('완료 ${counts[_WorkView.done] ?? 0}'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (picked) {
                  setState(() => _view = picked.first);
                  _touchDetail();
                },
              ),
            ),
            IconButton(
              tooltip: _searching ? '검색 닫기' : '검색',
              onPressed: () {
                setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _search.clear();
                    _query = '';
                  }
                });
                _touchDetail();
              },
              icon: Icon(
                _searching ? Icons.search_off_rounded : Icons.search_rounded,
              ),
            ),
            if (widget.embedded)
              IconButton(
                tooltip: '부서 요청',
                onPressed: _openRequests,
                icon: const Icon(Icons.forward_to_inbox_outlined),
              ),
          ],
        ),
        if (_searching) ...[
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: _search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() => _query = value);
              _touchDetail();
            },
            decoration: InputDecoration(
              hintText: '제목·내용·요청인·담당 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTokens.spaceSm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final scope in WorkTaskScope.values)
              ChoiceChip(
                label: Text(switch (scope) {
                  WorkTaskScope.all => '전체',
                  WorkTaskScope.mine => '내 업무',
                  WorkTaskScope.requested => '내가 요청',
                }),
                selected: _scope == scope,
                visualDensity: VisualDensity.compact,
                selectedColor: scheme.primaryContainer,
                onSelected: (_) {
                  setState(() => _scope = scope);
                  _touchDetail();
                },
              ),
          ],
        ),
      ],
    );
  }

  void _openRequests() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WorkRequestsScreen(),
        settings: const RouteSettings(name: WorkRequestsScreen.routeName),
      ),
    );
  }

  void _openDay(String day) {
    final ymd = day.length >= 10 ? day.substring(0, 10) : day;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.72;
        return ValueListenableBuilder<int>(
          valueListenable: _detailTick,
          builder: (context, _, _) {
            final board = _board;
            final tasks = <WorkTask>[
              if (board != null)
                for (final task in _scoped(board))
                  if (task.dueDate == ymd) task,
            ];
            tasks.sort((a, b) {
              final byPriority = workPriorityRank(
                a.priorityName,
              ).compareTo(workPriorityRank(b.priorityName));
              if (byPriority != 0) return byPriority;
              return a.title.compareTo(b.title);
            });
            return SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceLg,
                    ),
                    child: Text(
                      formatYmdFlowLabelKo(ymd),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Expanded(
                    child: tasks.isEmpty
                        ? const Center(child: Text('이 날 업무가 없습니다.'))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppTokens.spaceLg,
                              0,
                              AppTokens.spaceLg,
                              AppTokens.spaceSm,
                            ),
                            children: [
                              for (final task in tasks) ...[
                                _taskCard(task),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.spaceLg,
                        AppTokens.spaceSm,
                        AppTokens.spaceLg,
                        AppTokens.spaceMd,
                      ),
                      child: FilledButton(
                        onPressed: _busy ? null : () => _add(dueDate: ymd),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppTokens.minTouchTarget,
                          ),
                        ),
                        child: const Text('이 날 업무 추가'),
                      ),
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

  void _change(WorkTask task, String action) {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    _run(
      WorkTaskRepository(
        Supabase.instance.client,
      ).setStatus(userId: user.id, taskId: task.id, action: action),
      undoLabel:
          '「${task.title}」 ${task.isDone && action == 'receive' ? '다시 열기' : _actionLabel(action)}',
    );
  }

  static String _actionLabel(String action) => switch (action) {
    'start' => '시작',
    'complete' => '완료',
    'hold' => '보류',
    'receive' => '접수로 되돌림',
    _ => '변경',
  };

  /// 연구소 웹과 같이 상태를 바꾼 뒤 몇 초간 「실행 취소」 — 잘못 누른 완료·보류를 되돌린다.
  void _showUndo(String label, WorkTaskUndo undo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () {
              final user = ref.read(authControllerProvider);
              if (user == null || !mounted) return;
              _run(
                WorkTaskRepository(
                  Supabase.instance.client,
                ).restore(userId: user.id, undo: undo),
                doneMessage: '되돌렸습니다.',
              );
            },
          ),
        ),
      );
  }

  /// 상세 「수정」 — 바뀐 칸만 보낸다.
  Future<void> _edit(String id) async {
    final task = _taskById(id);
    final board = _board;
    final user = ref.read(authControllerProvider);
    if (task == null || board == null || user == null || _busy) return;
    final draft = await showModalBottomSheet<_NewWorkDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddWorkSheet(
        existing: task,
        assignees: visibleWorkAssignees(board.assignees),
        priorities: board.priorities,
        today: board.today,
        initialEmails: task.assigneeEmails,
        initialDue: task.dueDate,
        initialPriorityId: task.priorityId,
      ),
    );
    if (draft == null || !mounted) return;
    final edited = _WorkEditResult.diff(task, draft);
    if (!edited.hasChanges) return;
    await _run(
      WorkTaskRepository(Supabase.instance.client).update(
        userId: user.id,
        taskId: id,
        title: edited.title,
        detail: edited.detail,
        dueDate: edited.dueDate,
        priorityId: edited.priorityId,
        assigneeEmails: edited.assigneeEmails,
        requester: edited.requester,
      ),
      doneMessage: '수정했습니다.',
    );
  }

  Map<String, Color> _assigneeColors(WorkTaskBoard? board) {
    return workAssigneeColors(
      visibleWorkAssignees(
        board?.assignees ?? const [],
      ).map((person) => person.email),
    );
  }

  WorkTask? _taskById(String id) {
    final tasks = _board?.tasks;
    if (tasks == null) return null;
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _changeById(String id, String action) {
    final task = _taskById(id);
    if (task == null) return;
    _change(task, action);
  }

  void _openDetail(WorkTask task) {
    final id = task.id;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _WorkDetailPage(
          tick: _detailTick,
          lookup: () => _taskById(id),
          today: () => _board?.today ?? '',
          busy: () => _busy,
          colors: () => _assigneeColors(_board),
          onStart: () => _changeById(id, 'start'),
          onHold: () => _changeById(id, 'hold'),
          onComplete: () => _changeById(id, 'complete'),
          onReceive: () => _changeById(id, 'receive'),
          onEdit: () => unawaited(_edit(id)),
          loadComments: () => _loadComments(id),
          addComment: (content) => _addComment(id, content),
        ),
      ),
    );
  }

  Future<List<WorkComment>> _loadComments(String taskId) {
    final user = ref.read(authControllerProvider);
    if (user == null) return Future.value(const []);
    return WorkTaskRepository(
      Supabase.instance.client,
    ).comments(userId: user.id, taskId: taskId);
  }

  Future<List<WorkComment>> _addComment(String taskId, String content) {
    final user = ref.read(authControllerProvider);
    if (user == null) {
      return Future.error(ApiException('계정을 확인할 수 없습니다.'));
    }
    return WorkTaskRepository(
      Supabase.instance.client,
    ).addComment(userId: user.id, taskId: taskId, content: content);
  }

  Widget _taskCard(WorkTask task) {
    return _WorkLine(
      task: task,
      today: _board?.today ?? '',
      busy: _busy,
      assigneeColors: _assigneeColors(_board),
      onOpen: () => _openDetail(task),
      onStart: task.canStart ? () => _change(task, 'start') : null,
      onComplete: task.canComplete ? () => _change(task, 'complete') : null,
      onHold: task.canHold ? () => _change(task, 'hold') : null,
      onReopen: task.isDone ? () => _change(task, 'receive') : null,
    );
  }
}

enum _WorkView { open, held, done }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    this.alert = false,
  });

  final String label;
  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Text(
        '$label $count',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: alert ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _monthDay(String? ymd) {
  if (ymd == null || ymd.length < 10) return ymd ?? '';
  final month = int.tryParse(ymd.substring(5, 7));
  final day = int.tryParse(ymd.substring(8, 10));
  if (month == null || day == null) return ymd;
  return '$month/$day';
}

class _WorkLine extends StatelessWidget {
  const _WorkLine({
    required this.task,
    required this.today,
    required this.busy,
    required this.assigneeColors,
    this.onOpen,
    this.onStart,
    this.onComplete,
    this.onHold,
    this.onReopen,
  });

  final WorkTask task;
  final String today;
  final bool busy;
  final Map<String, Color> assigneeColors;
  final VoidCallback? onOpen;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onHold;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = workDueKind(task.dueDate, today);
    final dueLabel = task.isDone
        ? '완료 ${_monthDay(task.completedDate)}'
        : switch (due) {
            WorkDueKind.overdue => '기한 지남',
            WorkDueKind.today => '오늘',
            WorkDueKind.upcoming => _monthDay(task.dueDate),
            WorkDueKind.undated => '기한 없음',
          };
    final urgent = task.priorityName == '특급' && !task.isDone;
    final stripe = workTaskAssigneeColors(task, assigneeColors);
    final people = visibleTaskAssignees(
      task,
    ).map((person) => person.name).join(', ');
    final meta = [
      if (people.isNotEmpty) people,
      dueLabel,
      if (task.status.isNotEmpty && !task.isDone) task.status,
      if (!urgent && task.priorityName.isNotEmpty) task.priorityName,
    ].join(' · ');
    return Material(
      color: task.isDone
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : urgent
          ? scheme.errorContainer
          : due == WorkDueKind.overdue
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : due == WorkDueKind.today
          ? scheme.primaryContainer.withValues(alpha: 0.7)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 7,
                child: Column(
                  children: [
                    for (final color in stripe)
                      Expanded(child: ColoredBox(color: color)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (urgent) ...[
                            const _PriorityPill(name: '특급'),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (task.detail.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.detail.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      Row(
                        children: [
                          if (onStart != null)
                            _MiniButton(
                              label: '시작',
                              onPressed: busy ? null : onStart,
                            ),
                          if (onHold != null)
                            _MiniButton(
                              label: '보류',
                              onPressed: busy ? null : onHold,
                            ),
                          if (onReopen != null)
                            _MiniButton(
                              label: '다시 열기',
                              onPressed: busy ? null : onReopen,
                            ),
                          const Spacer(),
                          if (onComplete != null)
                            FilledButton(
                              onPressed: busy ? null : onComplete,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('완료'),
                            ),
                        ],
                      ),
                    ],
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

class _WorkDetailPage extends StatefulWidget {
  const _WorkDetailPage({
    required this.tick,
    required this.lookup,
    required this.today,
    required this.busy,
    required this.colors,
    required this.onStart,
    required this.onHold,
    required this.onComplete,
    required this.onReceive,
    required this.onEdit,
    required this.loadComments,
    required this.addComment,
  });

  final ValueNotifier<int> tick;
  final WorkTask? Function() lookup;
  final String Function() today;
  final bool Function() busy;
  final Map<String, Color> Function() colors;
  final VoidCallback onStart;
  final VoidCallback onHold;
  final VoidCallback onComplete;
  final VoidCallback onReceive;
  final VoidCallback onEdit;
  final Future<List<WorkComment>> Function() loadComments;
  final Future<List<WorkComment>> Function(String content) addComment;

  @override
  State<_WorkDetailPage> createState() => _WorkDetailPageState();
}

class _WorkDetailPageState extends State<_WorkDetailPage> {
  var _seen = false;
  var _closing = false;
  var _loadingComments = true;
  var _posting = false;
  String? _commentError;
  List<WorkComment> _comments = const [];
  final TextEditingController _draft = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reloadComments();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _reloadComments() async {
    try {
      final rows = await widget.loadComments();
      if (!mounted) return;
      setState(() {
        _comments = rows;
        _loadingComments = false;
        _commentError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
        _commentError = e is ApiException ? e.message : '댓글을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() {
      _posting = true;
      _commentError = null;
    });
    try {
      final rows = await widget.addComment(text);
      if (!mounted) return;
      _draft.clear();
      setState(() {
        _comments = rows;
        _posting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _commentError = e is ApiException ? e.message : '댓글을 등록하지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.tick,
      builder: (context, _, _) {
        final task = widget.lookup();
        if (task == null) {
          if (_seen && !_closing) {
            _closing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
          }
          return Scaffold(
            appBar: AppBar(title: const Text('업무')),
            body: const Center(child: Text('이 업무를 찾지 못했습니다.')),
          );
        }
        _seen = true;
        return _WorkDetailBody(
          task: task,
          today: widget.today(),
          busy: widget.busy(),
          assigneeColors: widget.colors(),
          onStart: task.canStart ? widget.onStart : null,
          onHold: task.canHold ? widget.onHold : null,
          onComplete: task.canComplete ? widget.onComplete : null,
          onReceive: task.canReceive ? widget.onReceive : null,
          onEdit: widget.onEdit,
          comments: _comments,
          loadingComments: _loadingComments,
          commentError: _commentError,
          draft: _draft,
          posting: _posting,
          onSubmitComment: _submitComment,
          onReloadComments: _reloadComments,
        );
      },
    );
  }
}

class _WorkDetailBody extends StatelessWidget {
  const _WorkDetailBody({
    required this.task,
    required this.today,
    required this.busy,
    required this.assigneeColors,
    this.onStart,
    this.onHold,
    this.onComplete,
    this.onReceive,
    this.onEdit,
    required this.comments,
    required this.loadingComments,
    required this.commentError,
    required this.draft,
    required this.posting,
    required this.onSubmitComment,
    required this.onReloadComments,
  });

  final WorkTask task;
  final String today;
  final bool busy;
  final Map<String, Color> assigneeColors;
  final VoidCallback? onStart;
  final VoidCallback? onHold;
  final VoidCallback? onComplete;
  final VoidCallback? onReceive;
  final VoidCallback? onEdit;
  final List<WorkComment> comments;
  final bool loadingComments;
  final String? commentError;
  final TextEditingController draft;
  final bool posting;
  final VoidCallback onSubmitComment;
  final VoidCallback onReloadComments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = workDueKind(task.dueDate, today);
    final dueText = switch (due) {
      WorkDueKind.overdue => '기한 지남 · ${formatYmdFlowLabelKo(task.dueDate!)}',
      WorkDueKind.today => '오늘 · ${formatYmdFlowLabelKo(task.dueDate!)}',
      WorkDueKind.upcoming => formatYmdFlowLabelKo(task.dueDate!),
      WorkDueKind.undated => '기한 없음',
    };
    final dueColor = due == WorkDueKind.overdue
        ? scheme.error
        : due == WorkDueKind.today
        ? scheme.primary
        : scheme.onSurface;
    final detail = task.detail.trim();
    final created = parseSupabaseTimestampUtc(task.createdAt);
    final createdLabel = created == null ? null : formatSeoulDateTime(created);
    final people = visibleTaskAssignees(task);
    return Scaffold(
      appBar: AppBar(
        title: const Text('업무'),
        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: '수정',
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          if (onReceive != null)
            PopupMenuButton<String>(
              tooltip: '더보기',
              enabled: !busy,
              onSelected: (_) => onReceive!(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'receive',
                  child: ListTile(
                    leading: Icon(Icons.undo_rounded),
                    title: Text('접수로 되돌리기'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceLg,
                AppTokens.spaceMd,
                AppTokens.spaceLg,
                AppTokens.spaceLg,
              ),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (task.priorityName.isNotEmpty)
                      _PriorityPill(name: task.priorityName),
                    if (task.status.isNotEmpty)
                      Text(
                        task.status,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                if (task.isDone && task.completedDate.isNotEmpty)
                  _DetailFact(
                    label: '완료',
                    value: formatYmdFlowLabelKo(task.completedDate),
                  ),
                InkWell(
                  onTap: busy ? null : onEdit,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: _DetailFact(
                    label: '기한',
                    value: dueText,
                    valueColor: dueColor,
                  ),
                ),
                if (people.isNotEmpty)
                  _DetailFact(
                    label: '담당',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final person in people)
                          _DetailPerson(
                            name: person.name,
                            color: person.email.isEmpty
                                ? scheme.outline
                                : workAssigneeColor(
                                    person.email,
                                    assigneeColors,
                                  ),
                          ),
                      ],
                    ),
                  )
                else if (task.assigneeNames.isEmpty &&
                    task.assigneeEmails.isEmpty)
                  const _DetailFact(label: '담당', value: '담당 없음'),
                if (task.requester.trim().isNotEmpty)
                  _DetailFact(label: '요청', value: task.requester.trim()),
                if (createdLabel != null)
                  _DetailFact(label: '만든 날짜', value: createdLabel),
                const SizedBox(height: AppTokens.spaceMd),
                Text(
                  '내용',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: busy || onEdit == null ? null : onEdit,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      detail.isEmpty ? '내용이 없습니다. 눌러서 쓰기' : detail,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                        color: detail.isEmpty ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceLg),
                Text(
                  '댓글',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                if (loadingComments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('댓글을 불러오는 중'),
                  )
                else if (comments.isEmpty)
                  Text(
                    '댓글이 없습니다.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final comment in comments) ...[
                    _CommentTile(comment: comment),
                    const SizedBox(height: 10),
                  ],
                if (commentError != null) ...[
                  const SizedBox(height: 6),
                  Text(commentError!, style: TextStyle(color: scheme.error)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onReloadComments,
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceLg,
              AppTokens.spaceSm,
              AppTokens.spaceLg,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: draft,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '댓글',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: posting ? null : onSubmitComment,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, AppTokens.minTouchTarget),
                  ),
                  child: Text(posting ? '등록 중' : '등록'),
                ),
              ],
            ),
          ),
          if (task.isDone && onReceive != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceLg,
                  AppTokens.spaceSm,
                  AppTokens.spaceLg,
                  AppTokens.spaceMd,
                ),
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReceive,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('다시 열기 (접수로)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      AppTokens.minTouchTarget,
                    ),
                  ),
                ),
              ),
            ),
          if (onStart != null || onHold != null || onComplete != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceLg,
                  AppTokens.spaceSm,
                  AppTokens.spaceLg,
                  AppTokens.spaceMd,
                ),
                child: Row(
                  children: [
                    if (onStart != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : onStart,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          child: const Text('시작'),
                        ),
                      ),
                    if (onHold != null) ...[
                      if (onStart != null)
                        const SizedBox(width: AppTokens.spaceSm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : onHold,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          child: const Text('보류'),
                        ),
                      ),
                    ],
                    if (onComplete != null) ...[
                      const SizedBox(width: AppTokens.spaceSm),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : onComplete,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppTokens.minTouchTarget,
                            ),
                          ),
                          child: const Text('완료'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({
    required this.label,
    this.value,
    this.valueColor,
    this.child,
  });

  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child:
                child ??
                Text(
                  value ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final WorkComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = parseSupabaseTimestampUtc(comment.createdAt);
    final stamp = when == null ? '' : formatSeoulDateTime(when);
    final author = comment.author.trim().isEmpty ? '이름 없음' : comment.author;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stamp.isEmpty ? author : '$author · $stamp',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(comment.content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _DetailPerson extends StatelessWidget {
  const _DetailPerson({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: workAssigneeInk(color),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label),
    );
  }
}

class _Pick extends StatelessWidget {
  const _Pick({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final solid = selected && color != null;
    final foreground = solid
        ? workAssigneeInk(accent)
        : selected
        ? accent
        : scheme.onSurface;
    return Material(
      color: solid
          ? accent
          : selected
          ? accent.withValues(alpha: 0.16)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
              color: selected ? accent : (color ?? scheme.outlineVariant),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null && !solid) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? foreground : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.name});

  final String name;

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _NewWorkDraft {
  const _NewWorkDraft({
    required this.title,
    required this.detail,
    required this.assigneeEmails,
    this.dueDate,
    this.priorityId,
    this.requester = '',
  });

  final String title;
  final String detail;
  final List<String> assigneeEmails;
  final String? dueDate;
  final String? priorityId;
  final String requester;
}

/// 수정 시트 결과 — 바뀐 칸만 값이 있다 (null = 그대로).
class _WorkEditResult {
  const _WorkEditResult({
    this.title,
    this.detail,
    this.dueDate,
    this.priorityId,
    this.assigneeEmails,
    this.requester,
  });

  /// 원래 업무와 비교해 바뀐 칸만 남긴다. 마감일을 지우면 ''.
  factory _WorkEditResult.diff(WorkTask task, _NewWorkDraft draft) {
    String? changed(String next, String prev) =>
        next.trim() == prev.trim() ? null : next.trim();
    final prevDue = (task.dueDate ?? '').trim();
    final prevDueYmd = prevDue.length >= 10 ? prevDue.substring(0, 10) : '';
    final nextDue = (draft.dueDate ?? '').trim();
    final sameAssignees =
        draft.assigneeEmails.toSet().containsAll(task.assigneeEmails) &&
        task.assigneeEmails.toSet().containsAll(draft.assigneeEmails);
    return _WorkEditResult(
      title: changed(draft.title, task.title),
      detail: changed(draft.detail, task.detail),
      dueDate: nextDue == prevDueYmd ? null : nextDue,
      priorityId: (draft.priorityId ?? '') == task.priorityId
          ? null
          : draft.priorityId,
      assigneeEmails: sameAssignees ? null : draft.assigneeEmails,
      requester: changed(draft.requester, task.requester),
    );
  }

  final String? title;
  final String? detail;
  final String? dueDate;
  final String? priorityId;
  final List<String>? assigneeEmails;
  final String? requester;

  bool get hasChanges =>
      title != null ||
      detail != null ||
      dueDate != null ||
      priorityId != null ||
      assigneeEmails != null ||
      requester != null;
}

class _AddWorkSheet extends StatefulWidget {
  const _AddWorkSheet({
    required this.assignees,
    required this.priorities,
    required this.today,
    this.initialEmails = const [],
    this.initialDue,
    this.initialPriorityId,
    this.existing,
  });

  final List<WorkAssignee> assignees;
  final List<WorkPriority> priorities;
  final String today;

  /// 처음 골라 둘 담당. 여러 명이면 모두.
  final List<String> initialEmails;
  final String? initialDue;
  final String? initialPriorityId;

  /// 있으면 「업무 수정」 — 제목·내용·요청인을 채워 열고 「저장」.
  final WorkTask? existing;

  @override
  State<_AddWorkSheet> createState() => _AddWorkSheetState();
}

class _AddWorkSheetState extends State<_AddWorkSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _detail = TextEditingController(
    text: widget.existing?.detail ?? '',
  );
  late final TextEditingController _requester = TextEditingController(
    text: widget.existing?.requester ?? '',
  );
  bool get _editing => widget.existing != null;
  late final List<String> _emails = _initialEmails();
  late final String? _ownHiddenEmail = _hiddenSelf();
  late String? _priorityId = _initialPriority();
  late String? _dueYmd = _initialDue();
  String? _error;

  String? _hiddenSelf() {
    for (final raw in widget.initialEmails) {
      final wanted = raw.trim();
      if (wanted.isNotEmpty && workAssigneeHidden(email: wanted)) return wanted;
    }
    return null;
  }

  List<String> _initialEmails() {
    final picked = <String>[
      for (final raw in widget.initialEmails)
        if (raw.trim().isNotEmpty &&
            (widget.assignees.any((person) => person.email == raw.trim()) ||
                workAssigneeHidden(email: raw.trim())))
          raw.trim(),
    ];
    if (picked.isEmpty && widget.assignees.length == 1) {
      picked.add(widget.assignees.first.email);
    }
    return picked;
  }

  /// 담당은 여러 명 고를 수 있다. 마지막 한 명은 빼지 않는다.
  void _toggleEmail(String email) {
    setState(() {
      if (_emails.contains(email)) {
        if (_emails.length > 1) _emails.remove(email);
      } else {
        _emails.add(email);
      }
      _error = null;
    });
  }

  String? _initialPriority() {
    final wanted = widget.initialPriorityId;
    if (wanted != null &&
        widget.priorities.any((priority) => priority.id == wanted)) {
      return wanted;
    }
    for (final priority in widget.priorities) {
      if (priority.name == '보통') return priority.id;
    }
    if (widget.priorities.isEmpty) return null;
    return widget.priorities.first.id;
  }

  String? _initialDue() {
    final due = (widget.initialDue ?? '').trim();
    if (due.length >= 10) return due.substring(0, 10);
    // 수정: 기한 없는 업무는 그대로 「없음」.
    if (_editing) return null;
    final today = widget.today.trim();
    if (today.length >= 10) return today.substring(0, 10);
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _requester.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final initial = _dateOf(_dueYmd) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      _dueYmd =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  DateTime? _dateOf(String? ymd) {
    final parts = (ymd ?? '').split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력해 주세요.');
      return;
    }
    if (_emails.isEmpty) {
      setState(() => _error = '담당자를 선택해 주세요.');
      return;
    }
    Navigator.pop(
      context,
      _NewWorkDraft(
        title: title,
        detail: _detail.text.trim(),
        assigneeEmails: List.of(_emails),
        dueDate: _dueYmd,
        priorityId: _priorityId,
        requester: _requester.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final today = widget.today.length >= 10
        ? widget.today.substring(0, 10)
        : '';
    final tomorrow = today.isEmpty ? '' : addDaysToYmd(today, 1);
    final dayAfter = today.isEmpty ? '' : addDaysToYmd(today, 2);
    final dueLabel = _dueYmd == null || _dueYmd!.isEmpty
        ? '기한 없음'
        : formatYmdFlowLabelKo(_dueYmd!);
    final customDue =
        _dueYmd != null &&
        _dueYmd != today &&
        _dueYmd != tomorrow &&
        _dueYmd != dayAfter;
    final urgent = widget.priorities.any(
      (priority) => priority.id == _priorityId && priority.name == '특급',
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
    );
    final fieldPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          0,
          AppTokens.spaceLg,
          AppTokens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? '업무 수정' : (urgent ? '특급 업무 추가' : '업무 추가'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  dueLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            TextField(
              controller: _title,
              autofocus: !_editing,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '제목',
                isDense: true,
                contentPadding: fieldPadding,
                border: fieldBorder,
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            _ChoiceRow(
              label: '기한',
              children: [
                if (today.isNotEmpty)
                  _Pick(
                    label: '오늘',
                    selected: _dueYmd == today,
                    onTap: () => setState(() => _dueYmd = today),
                  ),
                if (tomorrow.isNotEmpty)
                  _Pick(
                    label: '내일',
                    selected: _dueYmd == tomorrow,
                    onTap: () => setState(() => _dueYmd = tomorrow),
                  ),
                if (dayAfter.isNotEmpty)
                  _Pick(
                    label: '모레',
                    selected: _dueYmd == dayAfter,
                    onTap: () => setState(() => _dueYmd = dayAfter),
                  ),
                _Pick(
                  label: customDue ? dueLabel : '날짜',
                  selected: customDue,
                  onTap: _pickDue,
                ),
                _Pick(
                  label: '없음',
                  selected: _dueYmd == null,
                  onTap: () => setState(() => _dueYmd = null),
                ),
              ],
            ),
            if (widget.priorities.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceSm),
              _ChoiceRow(
                label: '중요',
                children: [
                  for (final priority in widget.priorities)
                    _Pick(
                      label: priority.name,
                      selected: _priorityId == priority.id,
                      color: workPriorityColor(scheme, priority.name),
                      onTap: () => setState(() => _priorityId = priority.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppTokens.spaceSm),
            if (widget.assignees.isEmpty && _emails.isEmpty)
              const Text('담당자 목록을 불러오지 못했습니다.')
            else
              _ChoiceRow(
                label: '담당',
                children: [
                  if (_ownHiddenEmail != null)
                    _Pick(
                      label: '나',
                      selected: _emails.contains(_ownHiddenEmail),
                      onTap: () => _toggleEmail(_ownHiddenEmail),
                    ),
                  for (final person in widget.assignees)
                    _Pick(
                      label: person.name,
                      selected: _emails.contains(person.email),
                      color: workAssigneeColor(
                        person.email,
                        workAssigneeColors(
                          widget.assignees.map((item) => item.email),
                        ),
                      ),
                      onTap: () => _toggleEmail(person.email),
                    ),
                ],
              ),
            const SizedBox(height: AppTokens.spaceSm),
            TextField(
              controller: _detail,
              minLines: 1,
              maxLines: _editing ? 6 : 2,
              decoration: InputDecoration(
                hintText: '내용 (선택)',
                isDense: true,
                contentPadding: fieldPadding,
                border: fieldBorder,
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: AppTokens.spaceSm),
              TextField(
                controller: _requester,
                decoration: InputDecoration(
                  hintText: '요청인 (선택)',
                  isDense: true,
                  contentPadding: fieldPadding,
                  border: fieldBorder,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: AppTokens.spaceSm),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(_editing ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, index) => children[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeBar extends StatelessWidget {
  const _AssigneeBar({
    required this.people,
    required this.selectedEmail,
    required this.colors,
    required this.busy,
    required this.onSelected,
    required this.onAdd,
  });

  final List<WorkAssignee> people;
  final String? selectedEmail;
  final Map<String, Color> colors;
  final bool busy;
  final ValueChanged<String?> onSelected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allSelected = selectedEmail == null || selectedEmail!.isEmpty;
    return Material(
      color: scheme.surface.withValues(alpha: 0),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
                children: [
                  _AssigneeChoice(
                    label: '전체',
                    selected: allSelected,
                    color: scheme.primary,
                    onTap: () => onSelected(null),
                  ),
                  for (final person in people)
                    if (person.email.isNotEmpty)
                      _AssigneeChoice(
                        label: person.name,
                        selected: selectedEmail == person.email,
                        color: workAssigneeColor(person.email, colors),
                        onTap: () => onSelected(person.email),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: busy ? null : onAdd,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('추가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneeChoice extends StatelessWidget {
  const _AssigneeChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = selected ? workAssigneeInk(color) : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected ? color : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!selected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
