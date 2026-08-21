import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

Future<String?> showSupportVisitDatePicker(
  BuildContext context, {
  required SupportCallLog log,
  String? selectedYmd,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _SupportVisitDatePickerSheet(log: log, selectedYmd: selectedYmd),
  );
}

class _SupportVisitDatePickerSheet extends ConsumerStatefulWidget {
  const _SupportVisitDatePickerSheet({required this.log, this.selectedYmd});

  final SupportCallLog log;
  final String? selectedYmd;

  @override
  ConsumerState<_SupportVisitDatePickerSheet> createState() =>
      _SupportVisitDatePickerSheetState();
}

class _SupportVisitDatePickerSheetState
    extends ConsumerState<_SupportVisitDatePickerSheet> {
  late DateTime _focused;
  DateTime? _selected;
  Map<String, int> _booked = const {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final today = todayYmdSeoul();
    final initial = (widget.selectedYmd ?? '').trim();
    _focused = _fromYmd(initial.isEmpty ? today : initial);
    if (initial.isNotEmpty) _selected = _fromYmd(initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
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

  String get _branch {
    final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];
    return matchSupportBranchType(widget.log.address ?? '', regions);
  }

  int get _capacity {
    final prefs = ref.read(appDependenciesProvider).prefs;
    return supportVisitDayCapacity(
      branch: _branch,
      hqTeams: supportVisitTeamsHq(prefs),
      branchTeams: supportVisitTeamsBranch(prefs),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final today = todayYmdSeoul();
      final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];
      final counts = await ref
          .read(supportCallLogRepositoryProvider)
          .countScheduledVisitsByYmd(
            fromYmd: today,
            toYmdInclusive: addDaysToYmd(today, 120),
            branch: _branch,
            regions: regions,
            excludeLogId: widget.log.id,
          );
      if (!mounted) return;
      setState(() {
        _booked = counts;
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

  bool _isOpen(DateTime day) {
    final today = _fromYmd(todayYmdSeoul());
    final start = DateTime(today.year, today.month, today.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(start)) return false;
    final booked = _booked[_toYmd(day)] ?? 0;
    return supportVisitDayOpen(booked: booked, capacity: _capacity);
  }

  void _pickEarliest() {
    final ymd = earliestOpenVisitYmd(
      fromYmd: todayYmdSeoul(),
      bookedByYmd: _booked,
      capacity: _capacity,
    );
    if (ymd == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('90일 안에 가능한 방문일이 없습니다.')));
      return;
    }
    Navigator.of(context).pop(ymd);
  }

  void _confirm() {
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('날짜를 선택해 주세요.')));
      return;
    }
    if (!_isOpen(selected)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 날은 방문 팀이 가득 찼습니다.')));
      return;
    }
    Navigator.of(context).pop(_toYmd(selected));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(regionsRawProvider, (prev, next) {
      if (next.hasValue) unawaited(_load());
    });
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final cap = _capacity;
    final branch = _branch;
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '방문예정일',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '$branch · 하루 $cap팀 · 자리가 있는 날만 고릅니다',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _pickEarliest,
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('가장 빠른 날짜'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  koreanErrorMessage(_error!),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            TableCalendar<void>(
              locale: 'ko_KR',
              firstDay: _fromYmd(todayYmdSeoul()),
              lastDay: _fromYmd(addDaysToYmd(todayYmdSeoul(), 120)),
              focusedDay: _focused,
              selectedDayPredicate: (d) =>
                  _selected != null && isSameDay(d, _selected),
              enabledDayPredicate: _isOpen,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              daysOfWeekHeight: 28,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              onDaySelected: (selected, focused) {
                if (!_isOpen(selected)) return;
                setState(() {
                  _selected = selected;
                  _focused = focused;
                });
              },
              onPageChanged: (focused) => setState(() => _focused = focused),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focused) =>
                    _cell(day, scheme: scheme, accent: accent),
                todayBuilder: (context, day, focused) =>
                    _cell(day, scheme: scheme, accent: accent, today: true),
                selectedBuilder: (context, day, focused) =>
                    _cell(day, scheme: scheme, accent: accent, selected: true),
                disabledBuilder: (context, day, focused) =>
                    _cell(day, scheme: scheme, accent: accent, disabled: true),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _confirm,
              child: const Text('이 날짜로 선택'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    DateTime day, {
    required ColorScheme scheme,
    required Color accent,
    bool selected = false,
    bool today = false,
    bool disabled = false,
  }) {
    final booked = _booked[_toYmd(day)] ?? 0;
    final cap = _capacity;
    final open =
        !disabled && supportVisitDayOpen(booked: booked, capacity: cap);
    final fg = selected
        ? Colors.white
        : !open
        ? scheme.onSurface.withValues(alpha: 0.35)
        : scheme.onSurface;
    return Center(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(color: accent, shape: BoxShape.circle)
            : today
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: fg,
              ),
            ),
            Text(
              '$booked/$cap',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : open
                    ? accent
                    : scheme.error.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
