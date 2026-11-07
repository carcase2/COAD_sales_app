import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/work_request_repository.dart';
import 'package:coad_customer_calls/models/work_request.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 부서 사이 업무 요청 — 받은 요청 / 보낸 요청. COAD_home 「부서 요청」과 같은 데이터.
class WorkRequestsScreen extends ConsumerStatefulWidget {
  const WorkRequestsScreen({super.key, this.initialRequestId});

  static const routeName = 'WorkRequests';

  /// 알림으로 열면 이 요청을 바로 연다.
  final String? initialRequestId;

  @override
  ConsumerState<WorkRequestsScreen> createState() => _WorkRequestsScreenState();
}

class _WorkRequestsScreenState extends ConsumerState<WorkRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  WorkRequestBoard? _board;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _showClosed = false;
  String? _pendingOpenId;

  @override
  void initState() {
    super.initState();
    _pendingOpenId = widget.initialRequestId;
    Future<void>.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant WorkRequestsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequestId != null &&
        widget.initialRequestId != oldWidget.initialRequestId) {
      _pendingOpenId = widget.initialRequestId;
      _openPending();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  WorkRequestRepository get _repo =>
      WorkRequestRepository(Supabase.instance.client);

  Future<void> _load() async {
    final user = ref.read(authControllerProvider);
    if (user == null) {
      setState(() {
        _loading = false;
        _error = ApiException('로그인이 필요합니다.');
      });
      return;
    }
    setState(() {
      _loading = _board == null;
      _error = null;
    });
    try {
      final board = await _repo.load(user.id);
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
      _openPending();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _openPending() {
    final id = (_pendingOpenId ?? '').trim();
    final board = _board;
    if (id.isEmpty || board == null) return;
    _pendingOpenId = null;
    WorkRequest? row;
    for (final item in board.requests) {
      if (item.id == id) row = item;
    }
    if (row == null) return;
    final found = row;
    final outgoing = board.outgoing.any((item) => item.id == found.id);
    final incoming = board.incoming.any((item) => item.id == found.id);
    if (outgoing && !incoming) _tabs.index = 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(found.id);
    });
  }

  Future<bool> _run(
    Future<WorkRequestBoard> Function(String userId) action, {
    String? done,
  }) async {
    final user = ref.read(authControllerProvider);
    if (user == null || _busy) return false;
    setState(() => _busy = true);
    try {
      final board = await action(user.id);
      if (!mounted) return false;
      setState(() => _board = board);
      if (done != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(done)));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '처리하지 못했습니다.')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final board = _board;
    if (board == null) return;
    if (board.targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청할 수 있는 부서가 없습니다.')));
      return;
    }
    final draft = await showModalBottomSheet<_RequestDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RequestSheet(
        today: board.today,
        targets: board.targets,
        priorities: board.priorities,
        fromGroup: board.viewer.groupName,
      ),
    );
    if (draft == null || !mounted) return;
    final ok = await _run(
      (userId) => _repo.create(
        userId: userId,
        toGroup: draft.toGroup,
        title: draft.title,
        detail: draft.detail,
        dueDate: draft.dueDate,
        priority: draft.priority,
      ),
      done: '${draft.toGroup}에 요청했습니다.',
    );
    if (ok && mounted) _tabs.animateTo(1);
  }

  Future<void> _edit(WorkRequest row) async {
    final board = _board;
    if (board == null) return;
    final draft = await showModalBottomSheet<_RequestDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RequestSheet(
        today: board.today,
        targets: [row.toGroup],
        priorities: board.priorities,
        fromGroup: row.fromGroup,
        existing: row,
      ),
    );
    if (draft == null || !mounted) return;
    await _run(
      (userId) => _repo.update(
        userId: userId,
        requestId: row.id,
        title: draft.title == row.title ? null : draft.title,
        detail: draft.detail == row.detail.trim() ? null : draft.detail,
        dueDate: (draft.dueDate ?? '') == row.dueDate
            ? null
            : (draft.dueDate ?? ''),
        priority: draft.priority == row.priority ? null : draft.priority,
      ),
      done: '요청을 고쳤습니다.',
    );
  }

  Future<void> _decide(WorkRequest row, String action) async {
    var note = '';
    if (action != 'accept') {
      final typed = await _askNote(action == 'reject' ? '거절 이유' : '보류 이유');
      if (typed == null) return;
      note = typed;
    }
    await _run(
      (userId) => _repo.decide(
        userId: userId,
        requestId: row.id,
        action: action,
        note: note,
      ),
      done: switch (action) {
        'accept' => '수락했습니다. 요청한 사람에게 알림이 갑니다.',
        'reject' => '거절했습니다.',
        _ => '보류했습니다.',
      },
    );
  }

  Future<String?> _askNote(String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '요청한 사람에게 보입니다 (선택)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _cancel(WorkRequest row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('요청을 취소할까요?'),
        content: Text('「${row.title}」 요청이 지워집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('요청 취소'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _run(
      (userId) => _repo.cancel(userId: userId, requestId: row.id),
      done: '요청을 취소했습니다.',
    );
  }

  Future<void> _progress(WorkRequest row, String progress) async {
    await _run(
      (userId) =>
          _repo.progress(userId: userId, requestId: row.id, progress: progress),
      done: progress == '완료'
          ? '완료했습니다. 요청한 사람에게 알림이 갑니다.'
          : '$progress(으)로 바꿨습니다.',
    );
  }

  WorkRequest? _byId(String id) {
    for (final row in _board?.requests ?? const <WorkRequest>[]) {
      if (row.id == id) return row;
    }
    return null;
  }

  void _openDetail(String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          final row = _byId(id);
          if (row == null) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('이 요청을 찾지 못했습니다.')),
            );
          }
          Future<void> act(Future<void> Function() action) async {
            await action();
            if (sheetContext.mounted) refresh(() {});
          }

          return _RequestDetail(
            row: row,
            today: _board?.today ?? '',
            busy: _busy,
            onAccept: () => act(() => _decide(row, 'accept')),
            onHold: () => act(() => _decide(row, 'hold')),
            onReject: () => act(() => _decide(row, 'reject')),
            onProgress: (value) => act(() => _progress(row, value)),
            onEdit: () => act(() => _edit(row)),
            onCancel: () async {
              await _cancel(row);
              if (sheetContext.mounted && _byId(id) == null) {
                Navigator.pop(sheetContext);
              }
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(workRequestsRefreshProvider, (previous, next) {
      if (previous != next) _load();
    });
    ref.listen<String?>(workRequestOpenProvider, (previous, next) {
      final id = (next ?? '').trim();
      if (id.isEmpty) return;
      _pendingOpenId = id;
      Future<void>.microtask(() {
        ref.read(workRequestOpenProvider.notifier).state = null;
      });
    });
    final board = _board;
    final waiting = board?.waitingCount ?? 0;
    final group = board?.viewer.groupName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(group.isEmpty ? '부서 요청' : '부서 요청 · $group'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: waiting > 0 ? '받은 요청 $waiting' : '받은 요청'),
            const Tab(text: '보낸 요청'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showClosed ? '끝난 요청 숨기기' : '끝난 요청 보기',
            onPressed: () => setState(() => _showClosed = !_showClosed),
            icon: Icon(
              _showClosed ? Icons.visibility_off_outlined : Icons.history,
            ),
          ),
        ],
      ),
      floatingActionButton: board == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.send_rounded),
              label: const Text('요청하기'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : board == null
          ? _ErrorView(error: _error, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                _list(board, board.incoming, incoming: true),
                _list(board, board.outgoing, incoming: false),
              ],
            ),
    );
  }

  Widget _list(
    WorkRequestBoard board,
    List<WorkRequest> rows, {
    required bool incoming,
  }) {
    final open = rows.where((row) => !row.isClosed).toList();
    final closed = rows.where((row) => row.isClosed).toList();
    final shown = _showClosed ? [...open, ...closed] : open;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          AppTokens.spaceMd,
          AppTokens.spaceLg,
          96,
        ),
        children: [
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                incoming
                    ? '받은 요청이 없습니다.'
                    : '보낸 요청이 없습니다.\n아래 「요청하기」로 다른 부서에 일을 맡길 수 있습니다.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final row in shown) ...[
            _RequestCard(
              row: row,
              today: board.today,
              incoming: incoming,
              busy: _busy,
              onOpen: () => _openDetail(row.id),
              onAccept: incoming && row.canDecide && row.needsAnswer
                  ? () => _decide(row, 'accept')
                  : null,
              onNext:
                  incoming &&
                      row.canDecide &&
                      nextWorkRequestProgress(row) != null
                  ? () => _progress(row, nextWorkRequestProgress(row)!)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          if (!_showClosed && closed.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _showClosed = true),
              child: Text('끝난 요청 ${closed.length}건 보기'),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is ApiException
                  ? (error! as ApiException).message
                  : '업무 요청을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

String requestDueText(String due, String today) {
  if (due.length < 10) return '기한 없음';
  if (today.length >= 10) {
    if (due == today.substring(0, 10)) return '오늘까지';
    if (due.compareTo(today.substring(0, 10)) < 0) {
      return '기한 지남 · ${formatYmdFlowLabelKo(due)}';
    }
  }
  return '${formatYmdFlowLabelKo(due)}까지';
}

Color _stateColor(ColorScheme scheme, WorkRequest row) {
  if (row.status == '요청') return scheme.primary;
  if (row.status == '보류') return scheme.tertiary;
  if (row.status == '거절') return scheme.error;
  if (row.progress == '완료') return scheme.outline;
  return scheme.secondary;
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.row,
    required this.today,
    required this.incoming,
    required this.busy,
    required this.onOpen,
    this.onAccept,
    this.onNext,
  });

  final WorkRequest row;
  final String today;
  final bool incoming;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = _stateColor(scheme, row);
    final route = incoming
        ? '${row.fromGroup} ${row.requesterName}'.trim()
        : '→ ${row.toGroup}';
    final next = nextWorkRequestProgress(row);
    final overdue =
        !row.isClosed &&
        row.dueDate.length >= 10 &&
        today.length >= 10 &&
        row.dueDate.compareTo(today.substring(0, 10)) < 0;
    return Material(
      color: row.needsAnswer && incoming
          ? scheme.primaryContainer.withValues(alpha: 0.6)
          : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Pill(label: row.stateLabel, color: state),
                  if (row.priority != '보통') ...[
                    const SizedBox(width: 6),
                    _Pill(
                      label: row.priority,
                      color: const {'특급', '긴급', '높음'}.contains(row.priority)
                          ? scheme.error
                          : scheme.outline,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [route, requestDueText(row.dueDate, today)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: overdue ? scheme.error : null,
                ),
              ),
              if (row.responseNote.isNotEmpty)
                Text(
                  '메모 ${row.responseNote}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (onAccept != null || (onNext != null && next != null))
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: FilledButton(
                      onPressed: busy ? null : (onAccept ?? onNext),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(72, 36),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        onAccept != null
                            ? '수락'
                            : next == '진행중'
                            ? '시작'
                            : '완료',
                      ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RequestDetail extends StatelessWidget {
  const _RequestDetail({
    required this.row,
    required this.today,
    required this.busy,
    required this.onAccept,
    required this.onHold,
    required this.onReject,
    required this.onProgress,
    required this.onEdit,
    required this.onCancel,
  });

  final WorkRequest row;
  final String today;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onHold;
  final VoidCallback onReject;
  final ValueChanged<String> onProgress;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final created = parseSupabaseTimestampUtc(row.createdAt);
    final responded = parseSupabaseTimestampUtc(row.respondedAt);
    final canAnswer = row.canDecide && row.decisionOpen && !row.isAccepted;
    final canChangeAnswer = row.canDecide && row.decisionOpen && row.isAccepted;
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: text.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyLarge)),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          0,
          AppTokens.spaceLg,
          AppTokens.spaceLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Pill(label: row.stateLabel, color: _stateColor(scheme, row)),
                const SizedBox(width: 6),
                _Pill(label: row.priority, color: scheme.outline),
                const Spacer(),
                if (row.canEdit)
                  TextButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('수정'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              row.title,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            fact('보낸 부서', '${row.fromGroup} · ${row.requesterName}'),
            fact('받는 부서', row.toGroup),
            fact('기한', requestDueText(row.dueDate, today)),
            if (created != null) fact('요청일', formatSeoulDateTime(created)),
            if (row.respondedBy.isNotEmpty)
              fact(
                '처리',
                [
                  row.respondedBy,
                  if (responded != null) formatSeoulDateTime(responded),
                ].join(' · '),
              ),
            if (row.responseNote.isNotEmpty) fact('메모', row.responseNote),
            if (row.detail.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                row.detail.trim(),
                style: text.bodyLarge?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: AppTokens.spaceLg),
            if (canAnswer) ...[
              FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
                ),
                child: const Text('수락'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (row.status != '보류')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onHold,
                        child: const Text('보류'),
                      ),
                    ),
                  if (row.status != '보류') const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      child: const Text('거절'),
                    ),
                  ),
                ],
              ),
            ],
            if (row.canDecide && row.isAccepted) ...[
              Text('진행', style: text.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: '접수', label: Text('접수')),
                  ButtonSegment(value: '진행중', label: Text('진행중')),
                  ButtonSegment(value: '완료', label: Text('완료')),
                ],
                selected: {row.progress.isEmpty ? '접수' : row.progress},
                onSelectionChanged: busy
                    ? null
                    : (picked) => onProgress(picked.first),
              ),
              if (canChangeAnswer)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : onHold,
                    child: const Text('수락 취소하고 보류'),
                  ),
                ),
            ],
            if (row.canCancel) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: const Text('요청 취소'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestDraft {
  const _RequestDraft({
    required this.toGroup,
    required this.title,
    required this.detail,
    required this.priority,
    this.dueDate,
  });

  final String toGroup;
  final String title;
  final String detail;
  final String priority;
  final String? dueDate;
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({
    required this.today,
    required this.targets,
    required this.priorities,
    required this.fromGroup,
    this.existing,
  });

  final String today;
  final List<String> targets;
  final List<String> priorities;
  final String fromGroup;
  final WorkRequest? existing;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _detail = TextEditingController(
    text: widget.existing?.detail ?? '',
  );
  late String? _toGroup =
      widget.existing?.toGroup ??
      (widget.targets.length == 1 ? widget.targets.first : null);
  late String _priority = widget.existing?.priority ?? '보통';
  late String? _due = (widget.existing?.dueDate ?? '').isEmpty
      ? null
      : widget.existing!.dueDate;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  String get _today =>
      widget.today.length >= 10 ? widget.today.substring(0, 10) : '';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      _due =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _save() {
    final title = _title.text.trim();
    final to = _toGroup;
    if (to == null || to.isEmpty) {
      setState(() => _error = '받을 부서를 골라 주세요.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력해 주세요.');
      return;
    }
    if (title.length > 120) {
      setState(() => _error = '제목은 120자까지 입력할 수 있습니다.');
      return;
    }
    Navigator.pop(
      context,
      _RequestDraft(
        toGroup: to,
        title: title,
        detail: _detail.text.trim(),
        priority: _priority,
        dueDate: _due,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final today = _today;
    final days = today.isEmpty
        ? const <(String, String)>[]
        : [
            ('오늘', today),
            ('내일', addDaysToYmd(today, 1)),
            ('모레', addDaysToYmd(today, 2)),
            ('1주 뒤', addDaysToYmd(today, 7)),
          ];
    final custom = _due != null && !days.any((day) => day.$2 == _due);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceLg,
          0,
          AppTokens.spaceLg,
          AppTokens.spaceLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _editing
                  ? '요청 수정'
                  : '${widget.fromGroup.isEmpty ? '' : '${widget.fromGroup}에서 '}다른 부서에 요청',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (!_editing) ...[
              label('받는 부서'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final group in widget.targets)
                    ChoiceChip(
                      label: Text(group),
                      selected: _toGroup == group,
                      onSelected: (_) => setState(() {
                        _toGroup = group;
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
            label('무엇을'),
            TextField(
              controller: _title,
              autofocus: _editing ? false : _toGroup != null,
              maxLength: 120,
              decoration: const InputDecoration(
                hintText: '제목',
                isDense: true,
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: '내용 (현장·수량·사진 위치 등)',
                isDense: true,
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            label('언제까지'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (name, ymd) in days)
                  ChoiceChip(
                    label: Text(name),
                    selected: _due == ymd,
                    onSelected: (_) => setState(() => _due = ymd),
                  ),
                ChoiceChip(
                  label: Text(custom ? formatYmdFlowLabelKo(_due!) : '날짜'),
                  selected: custom,
                  onSelected: (_) => _pickDate(),
                ),
                ChoiceChip(
                  label: const Text('없음'),
                  selected: _due == null,
                  onSelected: (_) => setState(() => _due = null),
                ),
              ],
            ),
            label('우선순위'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final priority in widget.priorities)
                  ChoiceChip(
                    label: Text(priority),
                    selected: _priority == priority,
                    selectedColor: const {'특급', '긴급'}.contains(priority)
                        ? scheme.errorContainer
                        : null,
                    onSelected: (_) => setState(() => _priority = priority),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: AppTokens.spaceMd),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
              ),
              child: Text(_editing ? '저장' : '요청 보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
