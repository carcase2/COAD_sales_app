import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_week_board.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomerSupportScheduleCalendarScreen extends ConsumerStatefulWidget {
  const CustomerSupportScheduleCalendarScreen({
    super.key,
    this.initialKind,
    this.initialVisitCompleted,
    this.initialBranch,
    this.initialYmd,
  });

  /// null 이면 방문+발송+입금 모두.
  final SupportScheduleKind? initialKind;
  /// 상태 필터: `false`=예정, `true`=완료. null이면 예정(`false`).
  /// 종류(전체/방문/발송/입금)와 무관하게 항상 적용.
  final bool? initialVisitCompleted;
  final String? initialBranch;
  final String? initialYmd;

  @override
  ConsumerState<CustomerSupportScheduleCalendarScreen> createState() =>
      _CustomerSupportScheduleCalendarScreenState();
}

class _CustomerSupportScheduleCalendarScreenState
    extends ConsumerState<CustomerSupportScheduleCalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;
  SupportScheduleKind? _kind;
  /// 상태 필터: false=예정, true=완료. 종류와 무관하게 항상 적용.
  late bool _phaseCompleted;
  String _branchTab = '전체';
  List<SupportScheduleEvent> _events = const [];
  Map<String, SupportAsVisitTeam> _teamsById = const {};
  bool _weekMode = true;
  bool _loading = true;
  Object? _error;
  bool _openedInitialDay = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _weekMode =
        widget.initialKind == null ||
        widget.initialKind == SupportScheduleKind.visit;
    _phaseCompleted = widget.initialVisitCompleted ?? false;
    final branch = (widget.initialBranch ?? '').trim();
    if (kSupportBranchTabOrder.contains(branch)) {
      _branchTab = branch;
    }
    final today = todayYmdSeoul();
    final ymd = (widget.initialYmd ?? '').trim();
    final raw = ymd.length >= 10 ? ymd : today;
    // 주간표는 월~금만 보이므로 주말 진입 시 다음 월요일로.
    final focus = supportVisitWeekFocusYmd(raw);
    _focused = _fromYmd(focus);
    _selected = _focused;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadMonth());
    });
  }

  DateTime _fromYmd(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(p[0]) ?? DateTime.now().year,
      int.tryParse(p[1]) ?? DateTime.now().month,
      int.tryParse(p[2]) ?? DateTime.now().day,
    );
  }

  String _toYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final focusedYmd = _toYmd(_focused);
      final range = _weekMode
          ? seoulWeekRangeContaining(supportVisitWeekFocusYmd(focusedYmd))
          : seoulMonthRangeContaining(focusedYmd);
      final rowsFuture = ref
          .read(supportCallLogRepositoryProvider)
          .listScheduleEvents(fromYmd: range.$1, toYmdInclusive: range.$2);
      final teamsFuture = ref
          .read(supportAsVisitTeamRepositoryProvider)
          .list(activeOnly: false);
      final rows = await rowsFuture;
      Map<String, SupportAsVisitTeam> teamsById = _teamsById;
      try {
        final teams = await teamsFuture;
        teamsById = {for (final t in teams) t.id: t};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _events = rows;
        _teamsById = teamsById;
        _loading = false;
      });
      final initial = (widget.initialYmd ?? '').trim();
      if (!_weekMode && !_openedInitialDay && initial.length >= 10) {
        _openedInitialDay = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showDayEventsSheet(_selected));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _siteName(SupportCallLog log) {
    final site = parseSupportIssueBody(log.issue).siteName.trim();
    if (site.isNotEmpty) return site;
    final name = log.customerName.trim();
    return name.isEmpty ? '(현장 없음)' : name;
  }

  SupportAsVisitTeam? _teamFor(SupportCallLog log) {
    final id = (log.visitTeamId ?? '').trim();
    if (id.isEmpty) return null;
    return _teamsById[id];
  }

  String _visitTimeLabel(SupportCallLog log) {
    final raw = (log.visitTime ?? '').trim();
    if (raw.isEmpty) return '';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  bool _isVisitCompleted(SupportScheduleEvent e) {
    if (e.kind != SupportScheduleKind.visit) return false;
    if (e.log.serviceStatusId == kSupportStatusCompleted) return true;
    final cap = (e.caption ?? '').trim();
    if (cap == '방문완료' || cap.startsWith('방문완료')) return true;
    final report = e.visitReport;
    if (report != null &&
        report.completed &&
        report.visitYmd.trim() == e.ymd.trim()) {
      return true;
    }
    return false;
  }

  bool _isEventCompleted(SupportScheduleEvent e) {
    switch (e.kind) {
      case SupportScheduleKind.visit:
        return _isVisitCompleted(e);
      case SupportScheduleKind.quoteSend:
        return e.quoteSent;
      case SupportScheduleKind.deposit:
        return e.depositPaid == true;
    }
  }

  List<SupportScheduleEvent> _applyKindFilter(List<SupportScheduleEvent> rows) {
    var out = rows;
    if (_kind != null) {
      out = out.where((e) => e.kind == _kind).toList();
    }
    out = out
        .where((e) => _isEventCompleted(e) == _phaseCompleted)
        .toList();
    return out;
  }

  List<SupportScheduleEvent> get _visible {
    var rows = _applyKindFilter(_events);
    if (_branchTab != '전체') {
      final regions = ref.watch(regionsRawProvider).valueOrNull ?? const [];
      rows = rows
          .where(
            (e) =>
                matchSupportBranchType(e.log.address ?? '', regions) ==
                _branchTab,
          )
          .toList();
    }
    return rows;
  }

  Map<String, int> _branchCounts() {
    final regions = ref.watch(regionsRawProvider).valueOrNull ?? const [];
    final source = _applyKindFilter(_events);
    final counts = <String, int>{'전체': source.length};
    for (final e in source) {
      final b = matchSupportBranchType(e.log.address ?? '', regions);
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts;
  }

  List<SupportScheduleEvent> _forDay(DateTime day) {
    final ymd = _toYmd(day);
    final rows = _visible.where((e) => e.ymd == ymd).toList();
    rows.sort((a, b) {
      final at = (a.scheduledTime ?? a.actualTime ?? _visitTimeLabel(a.log));
      final bt = (b.scheduledTime ?? b.actualTime ?? _visitTimeLabel(b.log));
      final kindOrder = a.kind.index.compareTo(b.kind.index);
      if (at.isNotEmpty || bt.isNotEmpty) {
        final t = at.compareTo(bt);
        if (t != 0) return t;
      }
      if (kindOrder != 0) return kindOrder;
      return _siteName(a.log).compareTo(_siteName(b.log));
    });
    return rows;
  }

  Future<void> _toggleQuoteSent(SupportScheduleEvent event) async {
    final id = (event.consultationId ?? '').trim();
    final raw = (event.consultationDescription ?? '').trim();
    if (id.isEmpty || raw.isEmpty) return;
    try {
      String? sentYmd;
      if (!event.quoteSent) {
        sentYmd = await askSupportQuoteSentYmd(context, plannedYmd: event.ymd);
        if (sentYmd == null || !mounted) return;
      }
      await ref
          .read(supportCallLogRepositoryProvider)
          .markQuoteSent(
            consultationId: id,
            description: raw,
            sentYmd: sentYmd,
          );
      if (mounted) await _loadMonth();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _toggleDepositPaid(SupportScheduleEvent event) async {
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
      if (mounted) await _loadMonth();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _open(SupportCallLog log) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CustomerSupportReceptionDetailScreen(log: log),
      ),
    );
    if (mounted) await _loadMonth();
  }

  Future<void> _showDayEventsSheet(DateTime day) async {
    final scheme = Theme.of(context).colorScheme;
    final sendColor = const Color(0xFFD97706);
    final depositColor = const Color(0xFF059669);
    final won = NumberFormat('#,###');
    final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModal) {
            final events = _forDay(day);
            Future<void> refresh() async {
              await _loadMonth();
              if (sheetContext.mounted) setModal(() {});
            }

            final media = MediaQuery.of(sheetContext);
            final bottom = media.viewPadding.bottom;
            final sheetH = (media.size.height - bottom) * 0.78;
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: SizedBox(
                height: sheetH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${day.month}월 ${day.day}일 · ${events.length}건',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: events.isEmpty
                          ? const AppEmpty(
                              icon: Icons.event_available_outlined,
                              message: '이 날 방문·발송·입금 일정이 없습니다.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                24,
                              ),
                              itemCount: events.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final e = events[i];
                                final branch = matchSupportBranchType(
                                  e.log.address ?? '',
                                  regions,
                                );
                                return _eventCard(
                                  e,
                                  scheme: scheme,
                                  sendColor: sendColor,
                                  depositColor: depositColor,
                                  won: won,
                                  branch: branch,
                                  onOpen: () async {
                                    await _open(e.log);
                                    if (sheetContext.mounted) setModal(() {});
                                  },
                                  onToggleDeposit: () async {
                                    await _toggleDepositPaid(e);
                                    await refresh();
                                  },
                                  onVisitReport: () async {
                                    final saved =
                                        await showSupportVisitReportSheet(
                                          context,
                                          log: e.log,
                                        );
                                    if (saved) await refresh();
                                  },
                                  onToggleQuote: () async {
                                    await _toggleQuoteSent(e);
                                    await refresh();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _eventCard(
    SupportScheduleEvent e, {
    required ColorScheme scheme,
    required Color sendColor,
    required Color depositColor,
    required NumberFormat won,
    required String branch,
    required Future<void> Function() onOpen,
    required Future<void> Function() onToggleDeposit,
    required Future<void> Function() onVisitReport,
    required Future<void> Function() onToggleQuote,
  }) {
    final visit = e.kind == SupportScheduleKind.visit;
    final deposit = e.kind == SupportScheduleKind.deposit;
    final color = visit
        ? scheme.tertiary
        : deposit
        ? depositColor
        : sendColor;
    final amountText = e.amount == null ? '' : '${won.format(e.amount)}원';
    final site = _siteName(e.log);
    final team = visit || deposit ? _teamFor(e.log) : null;
    final teamName = (team?.name ?? '').trim();
    final members = (team?.members ?? '').trim();
    final scheduled = _dayTimeLabel(e.scheduledYmd, e.scheduledTime);
    final actual = _dayTimeLabel(e.actualYmd, e.actualTime);
    final detailLines = <String>[
      [
        e.label,
        if (amountText.isNotEmpty) amountText,
      ].join(' · '),
      if (branch.isNotEmpty) '지사 $branch',
      if (teamName.isNotEmpty || members.isNotEmpty)
        [
          if (teamName.isNotEmpty) '팀 $teamName',
          if (members.isNotEmpty) members,
        ].join(' · '),
      if (visit) ...[
        '예정 ${scheduled.isEmpty ? '—' : scheduled}',
        '실제 ${actual.isEmpty ? '—' : actual}',
      ],
    ];
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => unawaited(onOpen()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  visit
                      ? Icons.event_available_rounded
                      : deposit
                      ? Icons.payments_outlined
                      : Icons.send_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    for (var li = 0; li < detailLines.length; li++)
                      Padding(
                        padding: EdgeInsets.only(top: li == 0 ? 0 : 2),
                        child: Text(
                          detailLines[li],
                          style: TextStyle(
                            color: li == 0 ? color : scheme.onSurfaceVariant,
                            fontWeight: li == 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: li == 0 ? 13 : 12.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (deposit)
                Checkbox(
                  value: e.depositPaid ?? false,
                  onChanged: (_) => unawaited(onToggleDeposit()),
                )
              else if (visit)
                IconButton(
                  tooltip: '방문 기록',
                  icon: const Icon(Icons.home_repair_service_outlined),
                  onPressed: () => unawaited(onVisitReport()),
                )
              else
                Checkbox(
                  value: e.quoteSent,
                  onChanged: (_) => unawaited(onToggleQuote()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayTimeLabel(String? ymd, String? time) {
    final d = (ymd ?? '').trim();
    final t = (time ?? '').trim();
    final t5 = t.length >= 5 ? t.substring(0, 5) : t;
    if (d.isEmpty && t5.isEmpty) return '';
    if (d.isEmpty) return t5;
    if (t5.isEmpty) return d;
    return '$d $t5';
  }

  static const _satColor = kSupportVisitCalendarSaturday;
  static const _sunColor = kSupportVisitCalendarSunday;

  static String _weekdayKo(int weekday) => switch (weekday) {
    DateTime.sunday => '일',
    DateTime.monday => '월',
    DateTime.tuesday => '화',
    DateTime.wednesday => '수',
    DateTime.thursday => '목',
    DateTime.friday => '금',
    DateTime.saturday => '토',
    _ => '',
  };

  static Color _weekdayColor(int weekday, ColorScheme scheme) =>
      switch (weekday) {
        DateTime.saturday => _satColor,
        DateTime.sunday => _sunColor,
        _ => scheme.onSurfaceVariant,
      };

  Widget _dayCell(
    DateTime day, {
    required ColorScheme scheme,
    required Color accent,
    required bool outside,
    bool selected = false,
    bool today = false,
  }) {
    final isToday = today || _toYmd(day) == todayYmdSeoul();
    final eventCount = outside ? 0 : _forDay(day).length;
    final weekend = switch (day.weekday) {
      DateTime.saturday => _satColor,
      DateTime.sunday => _sunColor,
      _ => null,
    };
    final Color fg;
    if (selected) {
      fg = Colors.white;
    } else if (weekend != null) {
      fg = outside ? weekend.withValues(alpha: 0.4) : weekend;
    } else {
      fg = outside
          ? scheme.onSurface.withValues(alpha: 0.35)
          : scheme.onSurface;
    }
    return Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? accent
              : isToday
              ? const Color(0xFFEFF6FF)
              : null,
          border: isToday
              ? Border.all(color: kSupportVisitWeekTodayBorder, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected || isToday
                    ? FontWeight.w800
                    : FontWeight.w600,
                height: 1.0,
                color: fg,
              ),
            ),
            Text(
              eventCount > 0 ? '$eventCount' : ' ',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : eventCount > 0
                    ? accent
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final sendColor = const Color(0xFFD97706);
    final depositColor = const Color(0xFF059669);
    final selectedCount = _forDay(_selected).length;
    final weekMon = seoulWeekRangeContaining(
      supportVisitWeekFocusYmd(_toYmd(_focused)),
    ).$1;
    return Scaffold(
      appBar: AppBar(
        title: Text(_weekMode ? '방문 주간표' : '방문 · 발송 달력'),
        actions: [
          IconButton(
            tooltip: _weekMode ? '월간 달력' : '주간표',
            onPressed: () {
              setState(() {
                _weekMode = !_weekMode;
                if (_weekMode) {
                  _kind = SupportScheduleKind.visit;
                  _phaseCompleted = false;
                }
              });
              unawaited(_loadMonth());
            },
            icon: Icon(
              _weekMode
                  ? Icons.calendar_month_rounded
                  : Icons.view_week_rounded,
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => unawaited(_loadMonth()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SupportBranchFilterBar(
            selected: _branchTab,
            counts: _branchCounts(),
            onSelected: (tab) => setState(() => _branchTab = tab),
          ),
          if (!_weekMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChip(
                  label: '일정 전체',
                  selected: _kind == null,
                  color: accent,
                  onTap: () => setState(() => _kind = null),
                ),
                _FilterChip(
                  label: '방문',
                  selected: _kind == SupportScheduleKind.visit,
                  color: scheme.tertiary,
                  onTap: () =>
                      setState(() => _kind = SupportScheduleKind.visit),
                ),
                _FilterChip(
                  label: '발송',
                  selected: _kind == SupportScheduleKind.quoteSend,
                  color: sendColor,
                  onTap: () =>
                      setState(() => _kind = SupportScheduleKind.quoteSend),
                ),
                _FilterChip(
                  label: '입금',
                  selected: _kind == SupportScheduleKind.deposit,
                  color: depositColor,
                  onTap: () =>
                      setState(() => _kind = SupportScheduleKind.deposit),
                ),
              ],
            ),
          ),
          if (!_weekMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChip(
                  label: '예정',
                  selected: !_phaseCompleted,
                  color: accent,
                  onTap: () => setState(() => _phaseCompleted = false),
                ),
                _FilterChip(
                  label: '완료',
                  selected: _phaseCompleted,
                  color: const Color(0xFF15803D),
                  onTap: () => setState(() => _phaseCompleted = true),
                ),
              ],
            ),
          ),
          if (_weekMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '이전 주',
                    onPressed: () {
                      setState(
                        () => _focused = _focused.subtract(
                          const Duration(days: 7),
                        ),
                      );
                      unawaited(_loadMonth());
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      formatMonthDayRangeKo(weekMon, addDaysToYmd(weekMon, 4)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final today = supportVisitWeekFocusYmd(todayYmdSeoul());
                      setState(() {
                        _focused = _fromYmd(today);
                        _selected = _focused;
                      });
                      unawaited(_loadMonth());
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      '오늘',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 주',
                    onPressed: () {
                      setState(
                        () => _focused = _focused.add(const Duration(days: 7)),
                      );
                      unawaited(_loadMonth());
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                koreanErrorMessage(_error!),
                style: TextStyle(color: scheme.error),
              ),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _weekMode
                ? SupportVisitWeekBoard(
                    anchorYmd: supportVisitWeekFocusYmd(_toYmd(_focused)),
                    events: _events,
                    teams: _teamsById.values.toList(),
                    branch: _branchTab,
                    onReload: _loadMonth,
                    onAnchorChanged: (ymd) {
                      setState(() {
                        _focused = _fromYmd(ymd);
                        _selected = _focused;
                      });
                      unawaited(_loadMonth());
                    },
                  )
                : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: TableCalendar<SupportScheduleEvent>(
                      locale: 'ko_KR',
                      firstDay: DateTime(2024, 1, 1),
                      lastDay: DateTime(2035, 12, 31),
                      focusedDay: _focused,
                      selectedDayPredicate: (d) => isSameDay(d, _selected),
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      daysOfWeekHeight: 28,
                      rowHeight: 48,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: 0),
                        weekendStyle: TextStyle(fontSize: 0),
                      ),
                      eventLoader: _forDay,
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selected = selected;
                          _focused = focused;
                        });
                        unawaited(_showDayEventsSheet(selected));
                      },
                      onPageChanged: (focused) {
                        final sameMonth =
                            focused.year == _focused.year &&
                            focused.month == _focused.month;
                        setState(() => _focused = focused);
                        if (!sameMonth) unawaited(_loadMonth());
                      },
                      calendarStyle: const CalendarStyle(
                        isTodayHighlighted: false,
                        todayDecoration: BoxDecoration(),
                        weekendTextStyle: TextStyle(fontSize: 0),
                        holidayTextStyle: TextStyle(fontSize: 0),
                      ),
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          return Center(
                            child: Text(
                              _weekdayKo(day.weekday),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                                color: _weekdayColor(day.weekday, scheme),
                              ),
                            ),
                          );
                        },
                        defaultBuilder: (context, day, focused) => _dayCell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          outside: false,
                        ),
                        todayBuilder: (context, day, focused) => _dayCell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          outside: false,
                          today: true,
                        ),
                        selectedBuilder: (context, day, focused) => _dayCell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          outside: false,
                          selected: true,
                          today: _toYmd(day) == todayYmdSeoul(),
                        ),
                        outsideBuilder: (context, day, focused) => _dayCell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          outside: true,
                          today: _toYmd(day) == todayYmdSeoul(),
                        ),
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          final hasVisit = events.any(
                            (e) => e.kind == SupportScheduleKind.visit,
                          );
                          final hasSend = events.any(
                            (e) => e.kind == SupportScheduleKind.quoteSend,
                          );
                          final hasDeposit = events.any(
                            (e) => e.kind == SupportScheduleKind.deposit,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasVisit)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: scheme.tertiary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasVisit && (hasSend || hasDeposit))
                                  const SizedBox(width: 3),
                                if (hasSend)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: sendColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (hasSend && hasDeposit)
                                  const SizedBox(width: 3),
                                if (hasDeposit)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: depositColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _weekMode
          ? null
          : SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '날짜를 누르면 일정을 크게 볼 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => unawaited(_showDayEventsSheet(_selected)),
                child: Text(
                  '${_selected.month}/${_selected.day} · $selectedCount건 보기',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Material(
      color: selected ? color : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
