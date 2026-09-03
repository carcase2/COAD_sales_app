import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomerSupportCollectionScreen extends ConsumerStatefulWidget {
  const CustomerSupportCollectionScreen({
    super.key,
    this.initialBranch,
    this.initialFilter,
  });

  final String? initialBranch;
  final String? initialFilter;

  @override
  ConsumerState<CustomerSupportCollectionScreen> createState() =>
      _CustomerSupportCollectionScreenState();
}

class _CustomerSupportCollectionScreenState
    extends ConsumerState<CustomerSupportCollectionScreen> {
  late DateTime _focused;
  late DateTime _selected;
  String _filter = 'due';
  String _branchTab = '전체';
  List<SupportScheduleEvent> _events = const [];
  bool _loading = true;
  Object? _error;
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    final today = DateTime.parse(todayYmdSeoul());
    _focused = today;
    _selected = today;
    final branch = (widget.initialBranch ?? '').trim();
    if (kSupportBranchTabOrder.contains(branch)) {
      _branchTab = branch;
    }
    final filter = (widget.initialFilter ?? '').trim();
    if (filter == 'all' ||
        filter == 'due' ||
        filter == 'overdue' ||
        filter == 'done') {
      _filter = filter;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  String _toYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final month = seoulMonthRangeContaining(_toYmd(_focused));
      final today = todayYmdSeoul();
      final monthRows = await ref
          .read(supportCallLogRepositoryProvider)
          .listScheduleEvents(fromYmd: month.$1, toYmdInclusive: month.$2);
      final dueRows = await ref
          .read(supportCallLogRepositoryProvider)
          .listDueScheduleEvents(todayYmd: today);
      final byKey = <String, SupportScheduleEvent>{};
      for (final e in [...dueRows, ...monthRows]) {
        if (e.kind != SupportScheduleKind.deposit) continue;
        byKey['${e.log.id}|${e.ymd}'] = e;
      }
      if (!mounted) return;
      setState(() {
        _events = byKey.values.toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<SupportScheduleEvent> get _branchSource {
    if (_branchTab == '전체') return _events;
    final regions = ref.watch(regionsRawProvider).valueOrNull ?? const [];
    return _events
        .where(
          (e) => supportBranchTabOf(e.log.address ?? '', regions) == _branchTab,
        )
        .toList(growable: false);
  }

  Map<String, int> _branchCounts() {
    final regions = ref.watch(regionsRawProvider).valueOrNull ?? const [];
    return supportBranchCounts(
      _events.map((e) => e.log.address ?? ''),
      regions,
    );
  }

  bool _matchesFilter(SupportScheduleEvent e) {
    final today = todayYmdSeoul();
    final paid = e.depositPaid == true;
    final overdue = !paid && e.ymd.compareTo(today) < 0;
    return switch (_filter) {
      'due' => !paid,
      'overdue' => overdue,
      'done' => paid,
      _ => true,
    };
  }

  List<SupportScheduleEvent> _onDay(DateTime day) {
    final ymd = _toYmd(day);
    return _branchSource
        .where((e) => e.ymd == ymd && _matchesFilter(e))
        .toList(growable: false);
  }

  int get _overdueCount {
    final today = todayYmdSeoul();
    return _branchSource
        .where((e) => e.depositPaid != true && e.ymd.compareTo(today) < 0)
        .length;
  }

  int get _dueAmount {
    var sum = 0;
    for (final e in _branchSource) {
      if (e.depositPaid == true) continue;
      sum += e.amount ?? 0;
    }
    return sum;
  }

  int get _doneAmount {
    var sum = 0;
    for (final e in _branchSource) {
      if (e.depositPaid != true) continue;
      sum += e.amount ?? 0;
    }
    return sum;
  }

  Future<void> _togglePaid(SupportScheduleEvent event) async {
    final report = event.visitReport;
    if (report == null || (report.id ?? '').isEmpty) return;
    try {
      final next = await nextSupportDepositPaidReport(
        context,
        report: report,
        currentlyPaid: event.depositPaid == true,
        plannedYmd: report.depositYmd ?? event.ymd,
      );
      if (next == null || !mounted) return;
      await ref.read(supportCallLogRepositoryProvider).updateVisitReport(next);
      invalidateSupportWorkCaches(ref);
      if (mounted) unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final dayEvents = _onDay(_selected);
    final overdue = _overdueCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('수금관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _events.isEmpty
          ? const AppLoading(message: '수금 일정을 불러오는 중…')
          : _error != null && _events.isEmpty
          ? AppEmpty(
              icon: Icons.cloud_off_outlined,
              message: '수금 일정을 불러오지 못했습니다.',
              detail: koreanErrorMessage(_error!),
              actionLabel: '다시 시도',
              onAction: () => unawaited(_load()),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                SupportBranchFilterBar(
                  selected: _branchTab,
                  counts: _branchCounts(),
                  onSelected: (tab) => setState(() => _branchTab = tab),
                ),
                const SizedBox(height: 8),
                if (overdue > 0)
                  Material(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: Icon(
                        Icons.notification_important_outlined,
                        color: scheme.onErrorContainer,
                      ),
                      title: Text(
                        '예정일이 지난 수금 $overdue건',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      subtitle: Text(
                        '탭하면 지난 입금만 봅니다.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                      onTap: () => setState(() => _filter = 'overdue'),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: '미수',
                        value: _dueAmount <= 0
                            ? '0'
                            : '${_won.format(_dueAmount)}원',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatBox(
                        label: '입금완료',
                        value: _doneAmount <= 0
                            ? '0'
                            : '${_won.format(_doneAmount)}원',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('전체'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('입금예정'),
                      selected: _filter == 'due',
                      onSelected: (_) => setState(() => _filter = 'due'),
                    ),
                    ChoiceChip(
                      label: const Text('지난'),
                      selected: _filter == 'overdue',
                      onSelected: (_) => setState(() => _filter = 'overdue'),
                    ),
                    ChoiceChip(
                      label: const Text('입금완료'),
                      selected: _filter == 'done',
                      onSelected: (_) => setState(() => _filter = 'done'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TableCalendar<SupportScheduleEvent>(
                  firstDay: DateTime(_focused.year - 1, 1, 1),
                  lastDay: DateTime(_focused.year + 1, 12, 31),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  eventLoader: _onDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selected = selectedDay;
                      _focused = focusedDay;
                    });
                  },
                  onPageChanged: (focused) {
                    _focused = focused;
                    unawaited(_load());
                  },
                  locale: 'ko_KR',
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '선택일 수금',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (dayEvents.isEmpty)
                  Text(
                    '이 날 입금 일정이 없습니다.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  for (final e in dayEvents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Checkbox(
                        value: e.depositPaid ?? false,
                        onChanged: (_) => unawaited(_togglePaid(e)),
                      ),
                      title: Text(
                        e.log.customerName.isEmpty
                            ? '(이름 없음)'
                            : e.log.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          if (e.depositPaid == true) ...[
                            '입금완료',
                            if ((e.actualYmd ?? '').isNotEmpty) e.actualYmd!,
                            if ((e.scheduledYmd ?? '').isNotEmpty &&
                                e.scheduledYmd != e.actualYmd)
                              '예정 ${e.scheduledYmd}',
                          ] else ...[
                            '입금예정',
                            e.ymd,
                          ],
                          if (e.amount != null) '${_won.format(e.amount)}원',
                        ].join(' · '),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CustomerSupportReceptionDetailScreen(
                                  log: e.log,
                                ),
                          ),
                        );
                        if (mounted) unawaited(_load());
                      },
                    ),
              ],
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
