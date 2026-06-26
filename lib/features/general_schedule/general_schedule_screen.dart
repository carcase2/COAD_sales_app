import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_form_screen.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_month_sheet.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_providers.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeneralScheduleScreen extends ConsumerStatefulWidget {
  const GeneralScheduleScreen({super.key});

  @override
  ConsumerState<GeneralScheduleScreen> createState() =>
      _GeneralScheduleScreenState();
}

class _GeneralScheduleScreenState extends ConsumerState<GeneralScheduleScreen> {
  final _dateStripKey = GlobalKey<_DateScrollStripState>();

  DateTime _selectedDay = DateTime.parse(todayYmdSeoul());
  String? _earliestAddCursorYmd;
  int _earliestAddCursorSlot = 0;
  String _searchQuery = '';

  Future<void> _reload() async {
    ref.invalidate(generalScheduleRecordsProvider);
    await ref.read(generalScheduleRecordsProvider.future);
  }

  String _ymd(DateTime d) => ymdSeoulFromDateTime(d);

  void _selectDay(String ymd) {
    if (_ymd(_selectedDay) == ymd) return;
    setState(() => _selectedDay = DateTime.parse(ymd));
  }

  void _goToToday() {
    _selectDayAndScroll(todayYmdSeoul());
  }

  void _selectDayAndScroll(String ymd) {
    setState(() => _selectedDay = DateTime.parse(ymd));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateStripKey.currentState?.scrollToCenter();
    });
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
    );
  }

  /// [current] 다음 **날짜**의 빈 칸 (당일 다른 칸은 건너뜀).
  EarliestAvailableSlot? _nextAvailableDay(
    GeneralScheduleDayGrid grid,
    EarliestAvailableSlot current,
  ) {
    return findNextAvailableDaySlot(grid, current: current);
  }

  void _setEarliestAddCursor(EarliestAvailableSlot slot) {
    _earliestAddCursorYmd = slot.ymd;
    _earliestAddCursorSlot = slot.slotIndex;
  }

  void _advanceEarliestAddCursorAfter(EarliestAvailableSlot slot) {
    _earliestAddCursorYmd = addDaysToYmd(slot.ymd, 1);
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
    _onDayTapped(_ymd(picked), ref.read(generalScheduleGridProvider));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정 정보를 불러오지 못했습니다.')),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ScheduleDetailSheet(
        record: record,
        slotIndex: slotIndex,
        ymd: ymd,
      ),
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
      await ref.read(generalScheduleRepositoryProvider).delete(record.id);
      final user = ref.read(authControllerProvider);
      unawaited(
        ref.read(generalScheduleRepositoryProvider).notifyTelegram(
              action: 'deleted',
              scheduleData: {
                'site': record.site,
                'start_date': record.start,
                'end_date': record.endDate,
                'user_name': user?.name ?? record.userName ?? '시스템',
                'sourceTab': 'general_schedule',
              },
            ),
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      _DialogSlotDots(activeIndex: slot.slotIndex, scheme: scheme),
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

  void _showDayFullMessage(String ymd) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${formatYmdFlowLabelKo(ymd)} — 빈 칸이 없습니다 (6/6 만석)',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 날짜 탭: 해당일로 이동 후 빈 칸이 있으면 등록, 없으면 안내.
  void _onDayTapped(String ymd, GeneralScheduleDayGrid grid) {
    setState(() => _selectedDay = DateTime.parse(ymd));
    final slots = grid[ymd] ?? emptyDaySlots();
    final emptyIndex = firstEmptySlotIndex(slots);
    if (emptyIndex == null) {
      _showDayFullMessage(ymd);
      return;
    }
    unawaited(_openAddForm(emptyIndex, ymd));
  }

  void _openMonthSheet(GeneralScheduleDayGrid grid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => GeneralScheduleMonthSheet(
        grid: grid,
        initialMonth: _selectedDay,
        onPickDay: (day) => _onDayTapped(_ymd(day), grid),
      ),
    );
  }

  ({String ymd, int slotIndex}) _recordPrimarySlot(GeneralScheduleRecord record) {
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

  Future<void> _openRecordFromSearch(GeneralScheduleRecord record) async {
    final primary = _recordPrimarySlot(record);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _ScheduleDetailSheet(
        record: record,
        slotIndex: primary.slotIndex,
        ymd: primary.ymd,
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openFullForm(editing: record);
    } else if (action == 'delete') {
      await _confirmDelete(record);
    }
  }

  Future<void> _openSearchResults() async {
    final records = ref.read(generalScheduleRecordsProvider).valueOrNull ?? [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검색할 일정이 없습니다.')),
      );
      return;
    }
    final selected = await showSearch<GeneralScheduleRecord?>(
      context: context,
      delegate: _GeneralScheduleSearchDelegate(records: records),
    );
    if (!mounted || selected == null) return;
    setState(() => _searchQuery = selected.site);
    await _openRecordFromSearch(selected);
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
        appBar: AppBar(title: const Text('본사일반 · test중')),
        body: const Center(
          child: Text('본사일반은 본사영업·관리자 부서만 이용할 수 있습니다.'),
        ),
      );
    }

    final recordsAsync = ref.watch(generalScheduleRecordsProvider);
    final grid = ref.watch(generalScheduleGridProvider);
    final scheme = Theme.of(context).colorScheme;
    final selectedYmd = _ymd(_selectedDay);
    final selectedMonthLabel = '${_selectedDay.year}년 ${_selectedDay.month}월';
    final dayStats = computeDayStats(grid, selectedYmd);
    final monthStats = computeMonthStats(
      grid,
      _selectedDay.year,
      _selectedDay.month,
    );
    final selectedWeekdayColor =
        generalScheduleWeekdayColor(_selectedDay.weekday);
    final scrollDays = List.generate(
      _DateScrollStrip.totalDays,
      (i) => addDaysToYmd(selectedYmd, i - _DateScrollStrip.centerIndex),
    );
    final isToday = selectedYmd == todayYmdSeoul();

    return Scaffold(
      appBar: AppBar(
        title: const Text('본사일반 · test중'),
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
            icon: Icon(
              Icons.today_rounded,
              color: isToday ? scheme.primary : null,
            ),
            tooltip: '오늘로 가기',
            onPressed: _goToToday,
          ),
          IconButton(
            icon: const Icon(Icons.event_note_rounded),
            tooltip: '월간 달력·통계',
            onPressed: () => _openMonthSheet(grid),
          ),
          IconButton(
            icon: const Icon(Icons.date_range_outlined),
            tooltip: '날짜 선택',
            onPressed: () => unawaited(_pickDate()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: recordsAsync.isLoading ? null : () => unawaited(_reload()),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(koreanErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(_reload()),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
        data: (_) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                child: Text(
                  selectedMonthLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              _DateScrollStrip(
                key: _dateStripKey,
                days: scrollDays,
                selectedYmd: selectedYmd,
                grid: grid,
                onTap: _selectDayAndScroll,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Text(
                  '${formatYmdFlowLabelKo(selectedYmd)} · '
                  '${dayStats.emptySlots == 0 ? '6/6 만석' : '${dayStats.usedSlots}/${dayStats.totalSlots}칸 · 남은 ${dayStats.emptySlots}'}'
                  '${_searchQuery.isEmpty ? '' : ' · 검색: $_searchQuery'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dayStats.emptySlots == 0
                            ? scheme.error
                            : selectedWeekdayColor ?? scheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GeneralScheduleStatsBar(
                dayStats: dayStats,
                monthStats: monthStats,
                compact: true,
                onOpenMonth: () => _openMonthSheet(grid),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _goToToday,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        icon: Icon(
                          Icons.today_rounded,
                          size: 16,
                          color: isToday ? scheme.primary : null,
                        ),
                        label: Text(
                          isToday ? '오늘' : '오늘로',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: recordsAsync.isLoading
                            ? null
                            : () => unawaited(_onQuickAddEarliest(grid)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 16),
                        label: const Text(
                          '빈 칸 추가',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
                  child: _DaySlotsPager(
                    days: scrollDays,
                    selectedYmd: selectedYmd,
                    grid: grid,
                    searchQuery: '',
                    onDayChanged: (ymd) {
                      _selectDay(ymd);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _dateStripKey.currentState?.scrollToCenter();
                      });
                    },
                    onSlotTap: _onSlotTap,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 날짜별 6칸 — 좌우 스와이프로 이전/다음 날 이동.
class _DaySlotsPager extends StatefulWidget {
  const _DaySlotsPager({
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.searchQuery,
    required this.onDayChanged,
    required this.onSlotTap,
  });

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final String searchQuery;
  final ValueChanged<String> onDayChanged;
  final void Function(int slotIndex, String ymd, GeneralScheduleCell? cell)
      onSlotTap;

  @override
  State<_DaySlotsPager> createState() => _DaySlotsPagerState();
}

class _DaySlotsPagerState extends State<_DaySlotsPager> {
  late final PageController _controller;
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _DateScrollStrip.centerIndex);
  }

  @override
  void didUpdateWidget(covariant _DaySlotsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYmd != widget.selectedYmd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSelectedDay());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToSelectedDay() {
    if (!_controller.hasClients) return;
    _programmaticPage = true;
    _controller.jumpToPage(_DateScrollStrip.centerIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _programmaticPage = false;
    });
  }

  void _onPageChanged(int index) {
    if (_programmaticPage || index < 0 || index >= widget.days.length) return;
    final ymd = widget.days[index];
    if (ymd == widget.selectedYmd) return;
    widget.onDayChanged(ymd);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.days.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, pageIndex) {
        final ymd = widget.days[pageIndex];
        final daySlots = widget.grid[ymd] ?? emptyDaySlots();
        return _DaySlotColumn(
          daySlots: daySlots,
          searchQuery: widget.searchQuery,
          onSlotTap: (slotIndex, cell) =>
              widget.onSlotTap(slotIndex, ymd, cell),
        );
      },
    );
  }
}

class _DaySlotColumn extends StatelessWidget {
  const _DaySlotColumn({
    required this.daySlots,
    required this.searchQuery,
    required this.onSlotTap,
  });

  final List<GeneralScheduleCell?> daySlots;
  final String searchQuery;
  final void Function(int slotIndex, GeneralScheduleCell? cell) onSlotTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.0;
        const slotCount = kGeneralScheduleSlotsPerDay;
        const extraBottomSpace = 16.0;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final gaps = gap * (slotCount - 1);
        final slotH =
            (constraints.maxHeight - gaps - bottomInset - extraBottomSpace) /
                slotCount;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset + extraBottomSpace),
          child: Column(
            children: [
              for (var index = 0; index < slotCount; index++) ...[
                if (index > 0) const SizedBox(height: gap),
                SizedBox(
                  height: slotH,
                  child: _SlotLaneCard(
                    slotIndex: index,
                    cell: daySlots[index],
                    searchQuery: searchQuery,
                    compact: true,
                    onTap: () => onSlotTap(index, daySlots[index]),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DateScrollStrip extends StatefulWidget {
  const _DateScrollStrip({
    super.key,
    required this.days,
    required this.selectedYmd,
    required this.grid,
    required this.onTap,
  });

  static const totalDays = 121;
  static const centerIndex = 60;
  static const itemWidth = 56.0;
  static const stripHeight = 80.0;

  final List<String> days;
  final String selectedYmd;
  final GeneralScheduleDayGrid grid;
  final ValueChanged<String> onTap;

  @override
  State<_DateScrollStrip> createState() => _DateScrollStripState();
}

class _DateScrollStripState extends State<_DateScrollStrip> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToCenter());
  }

  @override
  void didUpdateWidget(covariant _DateScrollStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedYmd != widget.selectedYmd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToCenter());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void scrollToCenter() {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final max = _controller.position.maxScrollExtent;
    final target =
        (_DateScrollStrip.centerIndex * _DateScrollStrip.itemWidth -
                (viewport - _DateScrollStrip.itemWidth) / 2)
            .clamp(0.0, max);
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: _DateScrollStrip.stripHeight,
        child: ListView.builder(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          itemCount: widget.days.length,
          itemBuilder: (context, i) {
              final ymd = widget.days[i];
              final parts = ymd.split('-');
              final dayNum =
                  parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
              final isSelected = ymd == widget.selectedYmd;
              final isToday = ymd == todayYmdSeoul();
              final isFull = isGeneralScheduleDayFull(widget.grid, ymd);
              final slots = widget.grid[ymd] ?? emptyDaySlots();
              final weekday = DateTime.parse(ymd).weekday;
              final weekendColor = generalScheduleWeekdayColor(weekday);

              return SizedBox(
                width: _DateScrollStrip.itemWidth,
                height: _DateScrollStrip.stripHeight - 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    color: isSelected
                        ? scheme.primary
                        : isFull
                            ? scheme.errorContainer.withValues(alpha: 0.55)
                            : isToday
                                ? scheme.primaryContainer
                                : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: isFull && !isSelected
                          ? BorderSide(
                              color: scheme.error.withValues(alpha: 0.7),
                              width: 1.5,
                            )
                          : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onTap(ymd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                weekdays[weekday - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : (weekendColor ??
                                          scheme.onSurfaceVariant),
                                ),
                              ),
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? scheme.onPrimary
                                      : isToday
                                          ? scheme.onPrimaryContainer
                                          : (weekendColor ??
                                              scheme.onSurface),
                                ),
                              ),
                              const SizedBox(height: 2),
                              _SlotMiniGrid(
                                slots: slots,
                                scheme: scheme,
                                onPrimary: isSelected,
                              ),
                              if (isFull)
                                Text(
                                  '만석',
                                  style: TextStyle(
                                    fontSize: 7,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? scheme.onPrimary
                                        : scheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    );
  }
}

class _SlotMiniGrid extends StatelessWidget {
  const _SlotMiniGrid({
    required this.slots,
    required this.scheme,
    this.onPrimary = false,
  });

  final List<GeneralScheduleCell?> slots;
  final ColorScheme scheme;
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kGeneralScheduleSlotsPerDay, (i) {
        final filled = slots[i] != null;
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: filled
                ? (onPrimary
                    ? scheme.onPrimary
                    : (parseGeneralScheduleUserColor(
                            slots[i]!.userColor,
                            fallback: scheme.primary,
                          )))
                : (onPrimary
                    ? scheme.onPrimary.withValues(alpha: 0.25)
                    : scheme.outlineVariant),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _SlotLaneCard extends StatelessWidget {
  const _SlotLaneCard({
    required this.slotIndex,
    required this.cell,
    required this.onTap,
    this.searchQuery = '',
    this.compact = false,
  });

  final int slotIndex;
  final GeneralScheduleCell? cell;
  final VoidCallback onTap;
  final String searchQuery;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = cell == null;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final isSearchMismatch = !isEmpty &&
        normalizedQuery.isNotEmpty &&
        !_generalScheduleCellMatchesQuery(cell!, normalizedQuery);
    final accent =
        isEmpty
            ? scheme.outline
            : (parseGeneralScheduleUserColor(
                cell!.userColor,
                fallback: scheme.primary,
              )!);

    final radius = compact ? 8.0 : 12.0;
    final badgeW = compact ? 36.0 : 52.0;
    final numSize = compact ? 17.0 : 22.0;

    return Material(
      color: isEmpty
          ? scheme.surface
          : isSearchMismatch
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: isEmpty
              ? scheme.outlineVariant
              : accent.withValues(alpha: 0.5),
          width: isEmpty ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox.expand(
          child: Row(
            children: [
            SizedBox(
              width: badgeW,
              child: Center(
                child: Text(
                  '${slotIndex + 1}',
                  style: TextStyle(
                    fontSize: numSize,
                    fontWeight: FontWeight.w800,
                    color: isEmpty ? scheme.onSurfaceVariant : accent,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, compact ? 4 : 10, 4, compact ? 4 : 10),
                child: isEmpty
                    ? Row(
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: scheme.primary,
                            size: compact ? 18 : 28,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              compact ? '탭하여 등록' : '빈 칸 — 기간·도어 등록',
                              style: TextStyle(
                                fontSize: compact ? 12 : 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : compact
                        ? Builder(
                            builder: (context) {
                              final doorLabel =
                                  formatGeneralScheduleDoorSummary(cell!);
                              final dayCount = inclusiveDayCount(
                                cell!.start,
                                cell!.endDate,
                              );
                              final assignee = (cell!.userName ?? '').trim();
                              final primaryLabel =
                                  assignee.isNotEmpty ? assignee : cell!.site;
                              final periodLabel =
                                  '${formatWeekRangeFlowLabel(cell!.start, cell!.endDate)} ($dayCount일)';
                              final summary = [
                                primaryLabel,
                                if (assignee.isNotEmpty) cell!.site,
                                if (doorLabel.isNotEmpty) doorLabel,
                                periodLabel,
                              ].join(' · ');
                              return Text(
                                isSearchMismatch ? '검색어와 일치하지 않음' : summary,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                  color: isSearchMismatch
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cell!.site,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Builder(
                                builder: (context) {
                                  final doorLabel =
                                      formatGeneralScheduleDoorSummary(cell!);
                                  final periodLabel =
                                      formatGeneralSchedulePeriodLabel(
                                    startYmd: cell!.start,
                                    endYmd: cell!.endDate,
                                  );
                                  final meta = [
                                    if (periodLabel.isNotEmpty)
                                      periodLabel
                                    else
                                      '${cell!.start} ~ ${cell!.endDate}',
                                    if (cell!.userName != null)
                                      cell!.userName!,
                                  ].where((s) => s.isNotEmpty).join(' · ');
                                  final subtitle = [
                                    if (doorLabel.isNotEmpty) doorLabel,
                                    if (meta.isNotEmpty) meta,
                                  ].join(' · ');
                                  if (subtitle.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    subtitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: doorLabel.isNotEmpty
                                              ? scheme.primary
                                              : scheme.onSurfaceVariant,
                                          fontWeight: doorLabel.isNotEmpty
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          fontSize: 11,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
              ),
            ),
            if (!isEmpty && !compact)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              () {
                final period = formatGeneralSchedulePeriodLabel(
                  startYmd: record.start,
                  endYmd: record.endDate,
                );
                if (period.isNotEmpty) return '기간: $period';
                return '기간: ${record.start}';
              }(),
            ),
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

bool _generalScheduleCellMatchesQuery(GeneralScheduleCell cell, String query) {
  if (query.isEmpty) return true;
  final haystack = cell.site.toLowerCase();
  return haystack.contains(query);
}

class _GeneralScheduleSearchDelegate extends SearchDelegate<GeneralScheduleRecord?> {
  _GeneralScheduleSearchDelegate({required this.records});

  final List<GeneralScheduleRecord> records;

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
    }).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

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
          title: Text(
            item.site,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (period.isNotEmpty) period else item.start,
              if ((item.userName ?? '').isNotEmpty) item.userName!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => close(context, item),
        );
      },
    );
  }
}

class _DialogSlotDots extends StatelessWidget {
  const _DialogSlotDots({
    required this.activeIndex,
    required this.scheme,
  });

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


