import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_schedule_filters.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 홈 달력 — 고객지원팀 방문예정 / 수금예정.
class HomeSupportCalendarPanel extends ConsumerStatefulWidget {
  const HomeSupportCalendarPanel({super.key, this.onRefresh});

  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<HomeSupportCalendarPanel> createState() =>
      _HomeSupportCalendarPanelState();
}

class _HomeSupportCalendarPanelState
    extends ConsumerState<HomeSupportCalendarPanel> {
  late DateTime _focused;
  late DateTime _selected;
  SupportHomeCalendarKind _kind = SupportHomeCalendarKind.visit;
  List<SupportScheduleEvent> _events = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.tryParse(todayYmdSeoul()) ?? DateTime.now();
    _focused = today;
    _selected = today;
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
      final range = seoulMonthRangeContaining(_toYmd(_focused));
      final rows = await ref
          .read(supportCallLogRepositoryProvider)
          .listScheduleEvents(fromYmd: range.$1, toYmdInclusive: range.$2);
      if (!mounted) return;
      setState(() {
        _events = rows;
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

  List<SupportScheduleEvent> _forDay(DateTime day) =>
      supportHomeCalendarEventsOnDay(
        _events,
        kind: _kind,
        ymd: _toYmd(day),
      );

  int _kindCount(SupportHomeCalendarKind kind) =>
      supportHomeCalendarEvents(_events, kind: kind).length;

  String _siteName(SupportCallLog log) {
    final site = parseSupportIssueBody(log.issue).siteName.trim();
    if (site.isNotEmpty) return site;
    final name = log.customerName.trim();
    return name.isEmpty ? '(현장 없음)' : name;
  }

  String _timeLabel(SupportScheduleEvent e) {
    final t = (e.scheduledTime ?? e.log.visitTime ?? '').trim();
    if (t.length >= 5) return t.substring(0, 5);
    return t;
  }

  Future<void> _open(SupportCallLog log) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionDetailScreen(log: log),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _visitReport(SupportCallLog log) async {
    final saved = await showSupportVisitReportSheet(context, log: log);
    if (saved && mounted) {
      invalidateSupportWorkCaches(ref);
      unawaited(_load());
    }
  }

  Future<void> _toggleDeposit(SupportScheduleEvent e) async {
    final report = e.visitReport;
    if (report == null || (report.id ?? '').isEmpty) return;
    try {
      final next = await nextSupportDepositPaidReport(
        context,
        report: report,
        currentlyPaid: e.depositPaid == true,
        plannedYmd: report.depositYmd ?? e.ymd,
      );
      if (next == null || !mounted) return;
      await ref.read(supportCallLogRepositoryProvider).updateVisitReport(next);
      invalidateSupportWorkCaches(ref);
      if (mounted) unawaited(_load());
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(err))));
    }
  }

  Future<void> _refresh() async {
    await _load();
    await widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final visitColor = scheme.tertiary;
    final depositColor = const Color(0xFF059669);
    final dayRows = _forDay(_selected);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: _KindChip(
                    label: '방문예정',
                    count: _kindCount(SupportHomeCalendarKind.visit),
                    selected: _kind == SupportHomeCalendarKind.visit,
                    color: visitColor,
                    onTap: () => setState(
                      () => _kind = SupportHomeCalendarKind.visit,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KindChip(
                    label: '수금예정',
                    count: _kindCount(SupportHomeCalendarKind.deposit),
                    selected: _kind == SupportHomeCalendarKind.deposit,
                    color: depositColor,
                    onTap: () => setState(
                      () => _kind = SupportHomeCalendarKind.deposit,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                koreanErrorMessage(_error!),
                style: TextStyle(color: scheme.error, fontSize: 12.5),
              ),
            ),
          TableCalendar<SupportScheduleEvent>(
            locale: 'ko_KR',
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime(2035, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: '월'},
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekHeight: 22,
            rowHeight: 40,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              headerPadding: EdgeInsets.only(bottom: 4),
            ),
            eventLoader: _forDay,
            onDaySelected: (selected, focused) {
              HapticFeedback.selectionClick();
              setState(() {
                _selected = selected;
                _focused = focused;
              });
            },
            onPageChanged: (focused) {
              final sameMonth =
                  focused.year == _focused.year &&
                  focused.month == _focused.month;
              setState(() => _focused = focused);
              if (!sameMonth) unawaited(_load());
            },
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: _kind == SupportHomeCalendarKind.visit
                    ? visitColor
                    : depositColor,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: accent.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_toYmd(_selected)} ${_kind == SupportHomeCalendarKind.visit ? '방문예정' : '수금예정'} · ${dayRows.length}건',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: dayRows.isEmpty
                ? AppEmpty(
                    message: _kind == SupportHomeCalendarKind.visit
                        ? '이 날짜에 방문예정이 없습니다.'
                        : '이 날짜에 수금예정이 없습니다.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: dayRows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = dayRows[i];
                      final visit = e.kind == SupportScheduleKind.visit;
                      final color = visit ? visitColor : depositColor;
                      final time = _timeLabel(e);
                      final amount = e.amount == null || e.amount! <= 0
                          ? ''
                          : formatSupportUnitPriceWon(e.amount);
                      return Material(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => unawaited(_open(e.log)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                            child: Row(
                              children: [
                                Icon(
                                  visit
                                      ? Icons.event_available_rounded
                                      : Icons.payments_outlined,
                                  color: color,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _siteName(e.log),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (visit && time.isNotEmpty) time,
                                          if (!visit && amount.isNotEmpty)
                                            amount,
                                          e.label,
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (visit)
                                  IconButton(
                                    tooltip: '방문 기록',
                                    onPressed: () =>
                                        unawaited(_visitReport(e.log)),
                                    icon: const Icon(
                                      Icons.home_repair_service_outlined,
                                    ),
                                  )
                                else
                                  Checkbox(
                                    value: e.depositPaid ?? false,
                                    onChanged: (_) =>
                                        unawaited(_toggleDeposit(e)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: selected ? color : scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: selected ? color : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
