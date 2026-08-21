import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
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
    this.initialBranch,
    this.initialYmd,
  });

  /// null 이면 방문+발송 모두.
  final SupportScheduleKind? initialKind;
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
  String _branchTab = '전체';
  List<SupportScheduleEvent> _events = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    final branch = (widget.initialBranch ?? '').trim();
    if (kSupportBranchTabOrder.contains(branch)) {
      _branchTab = branch;
    }
    final today = todayYmdSeoul();
    final ymd = (widget.initialYmd ?? '').trim();
    _focused = _fromYmd(ymd.length >= 10 ? ymd : today);
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

  List<SupportScheduleEvent> get _visible {
    var rows = _events;
    if (_kind != null) {
      rows = rows.where((e) => e.kind == _kind).toList();
    }
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
    final source = _kind == null
        ? _events
        : _events.where((e) => e.kind == _kind).toList();
    final counts = <String, int>{'전체': source.length};
    for (final e in source) {
      final b = matchSupportBranchType(e.log.address ?? '', regions);
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts;
  }

  List<SupportScheduleEvent> _forDay(DateTime day) {
    final ymd = _toYmd(day);
    return _visible.where((e) => e.ymd == ymd).toList();
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
      if (mounted) unawaited(_loadMonth());
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
      await ref
          .read(supportCallLogRepositoryProvider)
          .updateVisitReport(
            report.copyWith(depositPaid: !(event.depositPaid ?? false)),
          );
      if (mounted) unawaited(_loadMonth());
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
    if (mounted) unawaited(_loadMonth());
  }

  static const _satColor = Color(0xFF1565C0);
  static const _sunColor = Color(0xFFC62828);

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
        width: 36,
        height: 36,
        alignment: const Alignment(0, -0.08),
        decoration: selected
            ? BoxDecoration(color: accent, shape: BoxShape.circle)
            : today
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              )
            : null,
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected || today ? FontWeight.w800 : FontWeight.w600,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
            color: fg,
          ),
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
    final dayEvents = _forDay(_selected);
    final won = NumberFormat('#,###');
    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 · 발송 달력'),
        actions: [
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                koreanErrorMessage(_error!),
                style: TextStyle(color: scheme.error),
              ),
            ),
          TableCalendar<SupportScheduleEvent>(
            locale: 'ko_KR',
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime(2035, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            daysOfWeekHeight: 28,
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
            },
            onPageChanged: (focused) {
              final sameMonth =
                  focused.year == _focused.year &&
                  focused.month == _focused.month;
              setState(() => _focused = focused);
              if (!sameMonth) unawaited(_loadMonth());
            },
            calendarStyle: CalendarStyle(
              weekendTextStyle: const TextStyle(fontSize: 0),
              holidayTextStyle: const TextStyle(fontSize: 0),
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
                      leadingDistribution: TextLeadingDistribution.even,
                      color: _weekdayColor(day.weekday, scheme),
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focused) =>
                  _dayCell(day, scheme: scheme, accent: accent, outside: false),
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
              ),
              outsideBuilder: (context, day, focused) =>
                  _dayCell(day, scheme: scheme, accent: accent, outside: true),
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
                      if (hasSend && hasDeposit) const SizedBox(width: 3),
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
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.month}/${_selected.day} · ${dayEvents.length}건',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: dayEvents.isEmpty
                ? AppEmpty(
                    icon: Icons.event_available_outlined,
                    message: '이 날 방문·발송·입금 일정이 없습니다.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: dayEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = dayEvents[i];
                      final visit = e.kind == SupportScheduleKind.visit;
                      final deposit = e.kind == SupportScheduleKind.deposit;
                      final color = visit
                          ? scheme.tertiary
                          : deposit
                          ? depositColor
                          : sendColor;
                      final amountText = e.amount == null
                          ? ''
                          : '${won.format(e.amount)}원';
                      return Material(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Icon(
                            visit
                                ? Icons.event_available_rounded
                                : deposit
                                ? Icons.payments_outlined
                                : Icons.send_outlined,
                            color: color,
                          ),
                          title: Text(
                            e.log.customerName.isEmpty
                                ? '(이름 없음)'
                                : e.log.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              e.label,
                              if (amountText.isNotEmpty) amountText,
                            ].join(' · '),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: deposit
                              ? Checkbox(
                                  value: e.depositPaid ?? false,
                                  onChanged: (_) =>
                                      unawaited(_toggleDepositPaid(e)),
                                )
                              : visit
                              ? IconButton(
                                  tooltip: '방문 기록',
                                  icon: const Icon(
                                    Icons.home_repair_service_outlined,
                                  ),
                                  onPressed: () async {
                                    final saved =
                                        await showSupportVisitReportSheet(
                                          context,
                                          log: e.log,
                                        );
                                    if (saved && mounted) {
                                      unawaited(_loadMonth());
                                    }
                                  },
                                )
                              : Checkbox(
                                  value: e.quoteSent,
                                  onChanged: (_) =>
                                      unawaited(_toggleQuoteSent(e)),
                                ),
                          onTap: () => unawaited(_open(e.log)),
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
