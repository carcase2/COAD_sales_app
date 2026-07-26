import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_form_screen.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_calendar_ui.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_month_sheet.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_providers.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneralScheduleScreen extends ConsumerStatefulWidget {
  const GeneralScheduleScreen({super.key, this.embedded = false});

  /// 메인 하단 탭에 임베드될 때 true — 뒤로가기 대신 탭 전환으로 메인 이동.
  final bool embedded;

  @override
  ConsumerState<GeneralScheduleScreen> createState() =>
      _GeneralScheduleScreenState();
}

class _GeneralScheduleScreenState extends ConsumerState<GeneralScheduleScreen> {
  final _weekPanelKey = GlobalKey<GeneralScheduleWeekPanelState>();

  DateTime _selectedDay = DateTime.parse(todayYmdSeoul());
  String? _earliestAddCursorYmd;
  int _earliestAddCursorSlot = 0;
  String _searchQuery = '';
  String _selectedAssigneeFilter = kGeneralScheduleAllAssignees;
  GeneralScheduleCalendarView _calendarView = GeneralScheduleCalendarView.month;
  DateTime _monthFocusedDay = DateTime.parse(todayYmdSeoul());
  bool _returnToMonthViewOnBack = false;

  Future<void> _reload() async {
    ref.invalidate(generalScheduleRecordsProvider);
    await ref.read(generalScheduleRecordsProvider.future);
  }

  String _ymd(DateTime d) => ymdSeoulFromDateTime(d);

  /// 선택일 주변(날짜 스트립 ±60일)이 조회 구간 밖이면 하한을 앞당겨 재조회.
  void _ensureHistoryWindowCovers(String ymd) {
    final needed = addDaysToYmd(ymd, -GeneralScheduleWeekPanel.centerIndex);
    final current = ref.read(generalScheduleWindowStartProvider);
    if (needed.compareTo(current) < 0) {
      ref.read(generalScheduleWindowStartProvider.notifier).state = needed;
    }
  }

  void _goToToday() {
    HapticFeedback.selectionClick();
    final today = todayYmdSeoul();
    final todayDt = DateTime.parse(today);
    _ensureHistoryWindowCovers(today);
    setState(() {
      _selectedDay = todayDt;
      _monthFocusedDay = DateTime(todayDt.year, todayDt.month, 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _weekPanelKey.currentState?.scrollStripToCenter();
    });
  }

  void _selectDayAndScroll(String ymd, {bool fromMonthPick = false}) {
    _ensureHistoryWindowCovers(ymd);
    final changed = _ymd(_selectedDay) != ymd;
    if (!changed && !fromMonthPick) return;

    setState(() {
      if (changed) {
        _selectedDay = DateTime.parse(ymd);
        _monthFocusedDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      }
      if (fromMonthPick) {
        _calendarView = GeneralScheduleCalendarView.week;
        _returnToMonthViewOnBack = true;
      }
    });
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _weekPanelKey.currentState?.scrollStripToCenter();
      });
    }
  }

  void _switchToMonthView() {
    setState(() {
      _calendarView = GeneralScheduleCalendarView.month;
      _monthFocusedDay = DateTime(_selectedDay.year, _selectedDay.month, 1);
      _returnToMonthViewOnBack = false;
    });
  }

  void _onMonthDayPicked(DateTime day) {
    _selectDayAndScroll(_ymd(day), fromMonthPick: true);
  }

  /// [current] 이전 **날짜**의 빈 칸 (당일 다른 칸은 건너뜀).
  EarliestAvailableSlot? _previousAvailableDay(
    GeneralScheduleDayGrid grid,
    EarliestAvailableSlot current,
  ) {
    return findPreviousAvailableDaySlot(
      grid,
      current: current,
      minYmd: todayYmdSeoul(),
      skipWeekends: true,
    );
  }

  /// [current] 다음 **날짜**의 빈 칸 (당일 다른 칸은 건너뜀).
  EarliestAvailableSlot? _nextAvailableDay(
    GeneralScheduleDayGrid grid,
    EarliestAvailableSlot current,
  ) {
    return findNextAvailableDaySlot(grid, current: current, skipWeekends: true);
  }

  void _setEarliestAddCursor(EarliestAvailableSlot slot) {
    _earliestAddCursorYmd = slot.ymd;
    _earliestAddCursorSlot = slot.slotIndex;
  }

  void _advanceEarliestAddCursorAfter(EarliestAvailableSlot slot) {
    _earliestAddCursorYmd = nextWorkdayYmd(slot.ymd);
    _earliestAddCursorSlot = 0;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('ko', 'KR'),
    );
    if (picked == null || !mounted) return;
    _selectDayAndScroll(_ymd(picked));
  }

  Future<void> _openDetail(
    GeneralScheduleCell cell,
    int slotIndex,
    String ymd,
  ) async {
    final records = ref.read(generalScheduleRecordsProvider).valueOrNull ?? [];
    final record = findGeneralScheduleById(records, cell.scheduleId);
    if (record == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정 정보를 불러오지 못했습니다.')));
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) =>
          _ScheduleDetailSheet(record: record, slotIndex: slotIndex, ymd: ymd),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openFullForm(editing: record);
    } else if (action == 'delete') {
      await _confirmDelete(record);
    }
  }

  Future<void> _confirmDelete(GeneralScheduleRecord record) async {
    final firstOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('「${record.site}」 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (firstOk != true || !mounted) return;

    final finalOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '「${record.site}」 일정을 정말 삭제합니다.\n'
          '삭제된 일정은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (finalOk != true || !mounted) return;

    try {
      final repo = ref.read(generalScheduleRepositoryProvider);
      await repo.delete(record.id);
      final user = ref.read(authControllerProvider);
      try {
        await repo.dispatchGeneralScheduleNotification(
          action: 'deleted',
          base: {
            'site': record.site,
            'start_date': record.start,
            'end_date': record.endDate,
            'user_name': user?.name ?? record.userName ?? '시스템',
            'sourceTab': 'general_schedule',
          },
          record: record,
          actorName: user?.name ?? record.userName ?? '시스템',
        );
      } catch (e) {
        debugPrint('[general-schedule] push after delete failed: $e');
      }
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<bool> _openFullForm({
    GeneralScheduleRecord? editing,
    String? initialStartYmd,
    int? initialSlotIndex,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GeneralScheduleFormScreen(
          editing: editing,
          initialStartYmd: initialStartYmd,
          initialSlotIndex: initialSlotIndex,
        ),
      ),
    );
    if (saved == true) await _reload();
    return saved == true;
  }

  Future<bool> _openAddForm(int slotIndex, String ymd) =>
      _openFullForm(initialStartYmd: ymd, initialSlotIndex: slotIndex);

  Future<void> _onQuickAddEarliest(GeneralScheduleDayGrid grid) async {
    final today = todayYmdSeoul();
    var fromYmd = _earliestAddCursorYmd ?? today;
    var fromSlot = _earliestAddCursorYmd == null ? 0 : _earliestAddCursorSlot;
    if (fromYmd.compareTo(today) < 0) {
      fromYmd = today;
      fromSlot = 0;
    }

    final next = findEarliestAvailableSlot(
      grid,
      fromYmd: fromYmd,
      fromSlotIndex: fromSlot,
      skipWeekends: true,
    );
    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('앞으로 1년 내 빈 칸이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picked = <EarliestAvailableSlot>[next];
    _selectDayAndScroll(next.ymd);
    _setEarliestAddCursor(next);

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final slot = picked[0];
          final scheme = Theme.of(ctx).colorScheme;
          final prevDay = _previousAvailableDay(grid, slot);
          final nextDay = _nextAvailableDay(grid, slot);

          void moveTo(EarliestAvailableSlot target) {
            picked[0] = target;
            setDialogState(() {});
            _selectDayAndScroll(target.ymd);
            _setEarliestAddCursor(target);
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            title: Row(
              children: [
                Icon(Icons.event_available_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('빈 칸 추가'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatYmdFlowLabelKo(slot.ymd),
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '오늘 기준 ${formatDayOffsetFromTodayKo(slot.ymd)}',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${slot.slotIndex + 1}칸 배정 예정',
                        style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DialogSlotDots(
                        activeIndex: slot.slotIndex,
                        scheme: scheme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '해당 날짜에 일정을 추가할까요?',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: prevDay == null
                            ? null
                            : () => moveTo(prevDay),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: scheme.secondaryContainer,
                          foregroundColor: scheme.onSecondaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chevron_left_rounded, size: 20),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                '이전 날',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: nextDay == null
                            ? null
                            : () => moveTo(nextDay),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: scheme.tertiaryContainer,
                          foregroundColor: scheme.onTertiaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text(
                                '다음 날',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '토·일은 건너뜁니다',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text(
                          '취소',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, 'add'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text(
                          '일정추가',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!mounted || action != 'add') return;

    final slot = picked[0];
    _selectDayAndScroll(slot.ymd);
    final saved = await _openAddForm(slot.slotIndex, slot.ymd);
    if (!saved || !mounted) return;

    setState(() => _advanceEarliestAddCursorAfter(slot));
  }

  void _onSlotTap(int slotIndex, String ymd, GeneralScheduleCell? cell) {
    if (cell == null) {
      unawaited(_openAddForm(slotIndex, ymd));
    } else {
      unawaited(_openDetail(cell, slotIndex, ymd));
    }
  }

  List<String> _monthAssignees(
    GeneralScheduleMonthStats monthStats,
    String? loginUserName,
  ) {
    return sortGeneralScheduleAssignees([
      kGeneralScheduleAllAssignees,
      ...monthStats.byUser.map((u) => u.name),
    ], loginUserName: loginUserName);
  }

  Map<String, int> _monthAssigneeCounts(
    GeneralScheduleMonthStats monthStats,
    GeneralScheduleDayGrid grid,
    int year,
    int month,
  ) {
    final counts = <String, int>{
      kGeneralScheduleAllAssignees: monthStats.usedSlots,
    };
    for (final u in monthStats.byUser) {
      counts[u.name] = u.count;
    }
    return counts;
  }

  Color Function(String) _assigneeColorBuilder(
    GeneralScheduleMonthStats monthStats,
    ColorScheme scheme,
  ) {
    final colorMap = <String, Color>{};
    for (final u in monthStats.byUser) {
      colorMap[u.name] = parseGeneralScheduleUserColor(
        u.color,
        fallback: scheme.primary,
      )!;
    }
    return (name) {
      if (name == kGeneralScheduleAllAssignees) {
        return scheme.onSurfaceVariant;
      }
      if (name == '미지정') return scheme.outline;
      return colorMap[name] ?? scheme.primary;
    };
  }

  ({String ymd, int slotIndex}) _recordPrimarySlot(
    GeneralScheduleRecord record,
  ) {
    if (record.slots.isEmpty) {
      return (ymd: record.start, slotIndex: 0);
    }
    final slots = [...record.slots]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.slot.compareTo(b.slot);
      });
    final first = slots.first;
    return (
      ymd: first.date,
      slotIndex: first.slot.clamp(0, kGeneralScheduleSlotsPerDay - 1),
    );
  }

  Future<void> _openRecordFromSearch(
    BuildContext hostContext,
    GeneralScheduleRecord record,
  ) async {
    if (!mounted) return;
    setState(() => _searchQuery = record.site);

    var current = record;
    while (hostContext.mounted) {
      final primary = _recordPrimarySlot(current);
      final action = await showModalBottomSheet<String>(
        context: hostContext,
        showDragHandle: true,
        builder: (ctx) => _ScheduleDetailSheet(
          record: current,
          slotIndex: primary.slotIndex,
          ymd: primary.ymd,
        ),
      );
      if (!hostContext.mounted || action == null) return;
      if (action == 'edit') {
        final saved = await Navigator.of(hostContext).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => GeneralScheduleFormScreen(editing: current),
          ),
        );
        if (saved == true) {
          await _reload();
          if (!hostContext.mounted) return;
          final records =
              ref.read(generalScheduleRecordsProvider).valueOrNull ?? [];
          final refreshed = records
              .where((r) => r.id == current.id)
              .cast<GeneralScheduleRecord?>()
              .firstOrNull;
          if (refreshed == null) return;
          current = refreshed;
        }
        continue;
      }
      if (action == 'delete') {
        await _confirmDelete(current);
        return;
      }
    }
  }

  Future<void> _openSearchResults() async {
    final records = ref.read(generalScheduleRecordsProvider).valueOrNull ?? [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검색할 일정이 없습니다.')));
      return;
    }
    await showSearch<GeneralScheduleRecord?>(
      context: context,
      delegate: _GeneralScheduleSearchDelegate(
        records: records,
        onOpenRecord: _openRecordFromSearch,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    if (user == null || !canAccessGeneralSchedule(user)) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text('본사일반'),
          automaticallyImplyLeading: !widget.embedded,
        ),
        body: const Center(child: Text('본사일반은 본사영업·관리자 부서만 이용할 수 있습니다.')),
      );
    }

    final recordsAsync = ref.watch(generalScheduleRecordsProvider);
    final grid = ref.watch(generalScheduleGridProvider);
    final scheme = Theme.of(context).colorScheme;
    final selectedYmd = _ymd(_selectedDay);
    final statsAnchor = _calendarView == GeneralScheduleCalendarView.month
        ? _monthFocusedDay
        : _selectedDay;
    final selectedMonthLabel = '${statsAnchor.year}년 ${statsAnchor.month}월';
    final monthStats = computeMonthStats(
      grid,
      statsAnchor.year,
      statsAnchor.month,
    );
    final monthAssignees = _monthAssignees(monthStats, user.name);
    final monthAssigneeCounts = _monthAssigneeCounts(
      monthStats,
      grid,
      statsAnchor.year,
      statsAnchor.month,
    );
    final colorForAssignee = _assigneeColorBuilder(monthStats, scheme);
    final scrollDays = List.generate(
      GeneralScheduleWeekPanel.totalDays,
      (i) =>
          addDaysToYmd(selectedYmd, i - GeneralScheduleWeekPanel.centerIndex),
    );
    final isToday = selectedYmd == todayYmdSeoul();

    final scaffold = Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('본사일반'),
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: _searchQuery.isNotEmpty ? scheme.primary : null,
            ),
            tooltip: '전체 일정 검색',
            onPressed: _openSearchResults,
          ),
          IconButton(
            icon: recordsAsync.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
            onPressed: recordsAsync.isLoading
                ? null
                : () => unawaited(_reload()),
          ),
          IconButton(
            icon: Icon(
              Icons.today_rounded,
              color: isToday ? scheme.primary : null,
            ),
            tooltip: '오늘로 가기',
            onPressed: _goToToday,
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: (value) {
              switch (value) {
                case 'month':
                  _switchToMonthView();
                case 'pick':
                  unawaited(_pickDate());
                case 'refresh':
                  if (!recordsAsync.isLoading) unawaited(_reload());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'month',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_month_rounded),
                  title: Text('월간 보기'),
                ),
              ),
              const PopupMenuItem(
                value: 'pick',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.date_range_outlined),
                  title: Text('날짜 선택'),
                ),
              ),
              PopupMenuItem(
                value: 'refresh',
                enabled: !recordsAsync.isLoading,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('새로고침'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const AppLoading(message: '일정을 불러오는 중…'),
        error: (e, _) => AppErrorState(
          message: koreanErrorMessage(e),
          onRetry: () => unawaited(_reload()),
        ),
        data: (_) {
          final isWeekView = _calendarView == GeneralScheduleCalendarView.week;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  selectedMonthLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              GeneralScheduleCalendarViewToggle(
                view: _calendarView,
                onChanged: (view) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _calendarView = view;
                    if (view == GeneralScheduleCalendarView.month) {
                      _monthFocusedDay = DateTime(
                        _selectedDay.year,
                        _selectedDay.month,
                        1,
                      );
                      _returnToMonthViewOnBack = false;
                    }
                  });
                },
              ),
              GeneralScheduleAssigneeFilterBar(
                assignees: monthAssignees,
                counts: monthAssigneeCounts,
                selected: _selectedAssigneeFilter,
                colorForAssignee: colorForAssignee,
                onSelected: (name) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAssigneeFilter = name);
                },
              ),
              if (isWeekView)
                GeneralScheduleCollapsibleMonthStats(stats: monthStats),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _goToToday,
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppTokens.minTouchTarget),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(
                          Icons.today_rounded,
                          size: 18,
                          color: isToday ? scheme.primary : null,
                        ),
                        label: Text(
                          isToday ? '오늘' : '오늘로',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: recordsAsync.isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                unawaited(_onQuickAddEarliest(grid));
                              },
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppTokens.minTouchTarget),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor:
                              AppTokens.generalScheduleAccent(scheme),
                          foregroundColor: scheme.onPrimary,
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text(
                          '가장 빠른 빈 칸',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isWeekView
                    ? GeneralScheduleWeekPanel(
                        key: _weekPanelKey,
                        days: scrollDays,
                        selectedYmd: selectedYmd,
                        grid: grid,
                        assignees: monthAssignees,
                        assigneeCounts: monthAssigneeCounts,
                        selectedAssignee: _selectedAssigneeFilter,
                        colorForAssignee: colorForAssignee,
                        searchQuery: _searchQuery,
                        showAssigneeFilter: false,
                        onAssigneeChanged: (name) =>
                            setState(() => _selectedAssigneeFilter = name),
                        onDaySelected: _selectDayAndScroll,
                        onSlotTap: _onSlotTap,
                        onRefresh: _reload,
                        loginUserName: user.name,
                      )
                    : GeneralScheduleMonthCalendar(
                        grid: grid,
                        focusedMonth: _monthFocusedDay,
                        assigneeFilter: _selectedAssigneeFilter,
                        loginUserName: user.name,
                        onFocusedMonthChanged: (month) => setState(() {
                          _monthFocusedDay = DateTime(
                            month.year,
                            month.month,
                            1,
                          );
                        }),
                        onPickDay: _onMonthDayPicked,
                      ),
              ),
            ],
          );
        },
      ),
    );

    // 임베드 탭에서 월→주 복귀만 가로채고, 그 외 뒤로가기는 메인 PopScope가 홈으로 보냄.
    if (widget.embedded && !_returnToMonthViewOnBack) {
      return scaffold;
    }
    return PopScope(
      canPop: widget.embedded ? false : !_returnToMonthViewOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_returnToMonthViewOnBack) return;
        setState(() {
          _returnToMonthViewOnBack = false;
          _calendarView = GeneralScheduleCalendarView.month;
        });
      },
      child: scaffold,
    );
  }
}

class _ScheduleDetailSheet extends StatelessWidget {
  const _ScheduleDetailSheet({
    required this.record,
    required this.slotIndex,
    required this.ymd,
  });

  final GeneralScheduleRecord record;
  final int slotIndex;
  final String ymd;

  @override
  Widget build(BuildContext context) {
    final models = record.models;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              record.site,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(() {
              final period = formatGeneralSchedulePeriodLabel(
                startYmd: record.start,
                endYmd: record.endDate,
              );
              if (period.isNotEmpty) return '기간: $period';
              return '기간: ${record.start}';
            }()),
            Text('담당: ${record.userName ?? '—'}'),
            if (record.teamCount > 1) Text('팀 수: ${record.teamCount}'),
            Text('칸: ${slotIndex + 1} ($ymd)'),
            if (models.isNotEmpty) ...[
              const SizedBox(height: 4),
              const Text('도어 · 수량'),
              ...models.map((m) => Text('· ${m.name}: ${m.quantity}개')),
            ] else if (record.doorTypes.isNotEmpty)
              Text('도어: ${record.doorTypes.join(', ')}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'edit'),
                    child: const Text('수정'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, 'delete'),
                    child: const Text('삭제'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralScheduleSearchDelegate
    extends SearchDelegate<GeneralScheduleRecord?> {
  _GeneralScheduleSearchDelegate({
    required this.records,
    required this.onOpenRecord,
  });

  final List<GeneralScheduleRecord> records;
  final Future<void> Function(
    BuildContext context,
    GeneralScheduleRecord record,
  )
  onOpenRecord;

  @override
  String get searchFieldLabel => '현장명으로 검색';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final matches = records.where((r) {
      if (q.isEmpty) return true;
      return r.site.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.start.compareTo(a.start));

    if (matches.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = matches[i];
        final period = formatGeneralSchedulePeriodLabel(
          startYmd: item.start,
          endYmd: item.endDate,
        );
        return ListTile(
          leading: const Icon(Icons.event_note_rounded),
          title: Text(item.site, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              if (period.isNotEmpty) period else item.start,
              if ((item.userName ?? '').isNotEmpty) item.userName!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onOpenRecord(context, item),
        );
      },
    );
  }
}

class _DialogSlotDots extends StatelessWidget {
  const _DialogSlotDots({required this.activeIndex, required this.scheme});

  final int activeIndex;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
        final active = i == activeIndex;
        return Container(
          width: active ? 10 : 8,
          height: active ? 10 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.65),
            border: active
                ? Border.all(color: scheme.onPrimaryContainer, width: 1.5)
                : null,
          ),
        );
      }),
    );
  }
}
