import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class SupportVisitPickResult {
  const SupportVisitPickResult({
    required this.ymd,
    required this.teamId,
    required this.time,
    this.teamLabel,
  });

  final String ymd;
  final String teamId;
  final String time;
  final String? teamLabel;
}

Future<SupportVisitPickResult?> showSupportVisitDatePicker(
  BuildContext context, {
  required SupportCallLog log,
  String? selectedYmd,
  String? selectedTeamId,
  String? selectedTime,
}) {
  return showModalBottomSheet<SupportVisitPickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: false,
    builder: (_) => _SupportVisitDatePickerSheet(
      log: log,
      selectedYmd: selectedYmd,
      selectedTeamId: selectedTeamId,
      selectedTime: selectedTime,
    ),
  );
}

class _SupportVisitDatePickerSheet extends ConsumerStatefulWidget {
  const _SupportVisitDatePickerSheet({
    required this.log,
    this.selectedYmd,
    this.selectedTeamId,
    this.selectedTime,
  });

  final SupportCallLog log;
  final String? selectedYmd;
  final String? selectedTeamId;
  final String? selectedTime;

  @override
  ConsumerState<_SupportVisitDatePickerSheet> createState() =>
      _SupportVisitDatePickerSheetState();
}

class _SupportVisitDatePickerSheetState
    extends ConsumerState<_SupportVisitDatePickerSheet> {
  late DateTime _focused;
  DateTime? _selected;
  String? _teamId;
  String? _time;
  List<SupportAsVisitTeam> _teams = const [];
  Map<String, SupportVisitDayBookings> _bookings = const {};
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final today = todayYmdSeoul();
    final initial = (widget.selectedYmd ?? '').trim();
    _focused = _fromYmd(initial.isEmpty ? today : initial);
    if (initial.isNotEmpty) _selected = _fromYmd(initial);
    _teamId = (widget.selectedTeamId ?? '').trim().isEmpty
        ? null
        : widget.selectedTeamId!.trim();
    final t = normalizeSupportVisitTime(widget.selectedTime);
    _time = t.isEmpty ? null : t;
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

  int get _slotCap => supportVisitDaySlotCapacity(_teams.length);

  Iterable<String> get _teamIds => _teams.map((t) => t.id);

  SupportVisitDayBookings _dayBookings(String ymd) =>
      _bookings[ymd] ?? const SupportVisitDayBookings();

  List<String> _freeTimesForTeam(String ymd, String teamId) =>
      supportVisitFreeTimesForTeam(
        teamId: teamId,
        bookings: _dayBookings(ymd),
      );

  void _syncTeamAndTime(String ymd) {
    if (_teams.isEmpty) {
      _teamId = null;
      _time = null;
      return;
    }
    if (_teamId == null || !_teams.any((t) => t.id == _teamId)) {
      _teamId = _teams.first.id;
    }
    final free = _freeTimesForTeam(ymd, _teamId!);
    if (_time != null && free.contains(_time)) return;
    _time = free.isEmpty ? null : free.first;
  }

  bool _isOpen(DateTime day) {
    final today = _fromYmd(todayYmdSeoul());
    final start = DateTime(today.year, today.month, today.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(start)) return false;
    final ymd = _toYmd(day);
    return supportVisitDaySelectable(
      bookings: _dayBookings(ymd),
      activeTeamCount: _teams.length,
      activeTeamIds: _teamIds,
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
      final teams = await ref
          .read(supportAsVisitTeamRepositoryProvider)
          .listForBranch(_branch, activeOnly: true);
      final bookings = await ref
          .read(supportCallLogRepositoryProvider)
          .listScheduledVisitsByYmd(
            fromYmd: today,
            toYmdInclusive: addDaysToYmd(today, 120),
            branch: _branch,
            regions: regions,
            excludeLogId: widget.log.id,
          );
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _bookings = bookings;
        _loading = false;
        if (_selected != null) {
          _syncTeamAndTime(_toYmd(_selected!));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _pickEarliest() {
    final ymd = earliestOpenVisitYmdWithTeams(
      fromYmd: todayYmdSeoul(),
      bookingsByYmd: _bookings,
      activeTeamCount: _teams.length,
      activeTeamIds: _teamIds,
    );
    if (ymd == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('90일 안에 가능한 방문일이 없습니다.')));
      return;
    }
    final day = _fromYmd(ymd);
    setState(() {
      _selected = day;
      _focused = day;
      _syncTeamAndTime(ymd);
    });
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
      ).showSnackBar(const SnackBar(content: Text('이 날은 방문 일정이 가득 찼습니다.')));
      return;
    }
    final teamId = (_teamId ?? '').trim();
    if (teamId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문 팀을 선택해 주세요.')));
      return;
    }
    final time = normalizeSupportVisitTime(_time);
    if (time.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문 시간을 선택해 주세요.')));
      return;
    }
    final ymd = _toYmd(selected);
    if (!supportVisitTeamTimeFree(
      teamId: teamId,
      time: time,
      bookings: _dayBookings(ymd),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 팀은 그 시간에 이미 일정이 있습니다.')),
      );
      return;
    }
    SupportAsVisitTeam? team;
    for (final t in _teams) {
      if (t.id == teamId) {
        team = t;
        break;
      }
    }
    Navigator.of(context).pop(
      SupportVisitPickResult(
        ymd: ymd,
        teamId: teamId,
        time: time,
        teamLabel: team?.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(regionsRawProvider, (prev, next) {
      if (next.hasValue) unawaited(_load());
    });
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final slotCap = _slotCap;
    final branch = _branch;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;
    final height = media.size.height * 0.9;
    final selectedYmd = _selected == null ? null : _toYmd(_selected!);
    final dayBookings = selectedYmd == null
        ? const SupportVisitDayBookings()
        : _dayBookings(selectedYmd);

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '방문예정일',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              slotCap <= 0
                  ? '$branch · 등록된 팀이 없습니다. 설정에서 팀을 추가해 주세요'
                  : '$branch · 날짜 → 팀 → 시간. 같은 팀은 다른 시간이면 하루 여러 곳 가능',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: _loading || slotCap <= 0 ? null : _pickEarliest,
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                      rowHeight: 44,
                      daysOfWeekHeight: 24,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        headerPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onDaySelected: (selected, focused) {
                        if (!_isOpen(selected)) return;
                        final ymd = _toYmd(selected);
                        setState(() {
                          _selected = selected;
                          _focused = focused;
                          _syncTeamAndTime(ymd);
                        });
                      },
                      onPageChanged: (focused) =>
                          setState(() => _focused = focused),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focused) =>
                            _cell(day, scheme: scheme, accent: accent),
                        todayBuilder: (context, day, focused) => _cell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          today: true,
                        ),
                        selectedBuilder: (context, day, focused) => _cell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          selected: true,
                        ),
                        disabledBuilder: (context, day, focused) => _cell(
                          day,
                          scheme: scheme,
                          accent: accent,
                          disabled: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedYmd == null
                          ? '날짜를 먼저 선택해 주세요'
                          : '방문 팀',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (selectedYmd != null && _teams.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final team in _teams)
                            _TeamChip(
                              team: team,
                              selected: _teamId == team.id,
                              visitCount: dayBookings.visitsForTeam(team.id),
                              accent: accent,
                              onTap: () => setState(() {
                                _teamId = team.id;
                                _syncTeamAndTime(selectedYmd);
                              }),
                            ),
                        ],
                      ),
                    if (selectedYmd != null && (_teamId ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '방문 시간',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final slot in kSupportVisitTimeSlots)
                            _TimeChip(
                              time: slot,
                              selected: _time == slot,
                              taken: dayBookings.teamTimeTaken(
                                teamId: _teamId!,
                                time: slot,
                              ),
                              accent: accent,
                              onTap: dayBookings.teamTimeTaken(
                                    teamId: _teamId!,
                                    time: slot,
                                  )
                                  ? null
                                  : () => setState(() => _time = slot),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: _loading || slotCap <= 0 ? null : _confirm,
              child: const Text('이 날짜·팀·시간으로 선택'),
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
    final ymd = _toYmd(day);
    final booked = _dayBookings(ymd).totalCount;
    final cap = _slotCap;
    final open = !disabled && _isOpen(day);
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
              cap <= 0 ? '-' : '$booked',
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

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.team,
    required this.selected,
    required this.visitCount,
    required this.accent,
    required this.onTap,
  });

  final SupportAsVisitTeam team;
  final bool selected;
  final int visitCount;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(
        visitCount > 0 ? '${team.label} · $visitCount건' : team.label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? accent : scheme.onSurface,
        ),
      ),
      selectedColor: accent.withValues(alpha: 0.16),
      checkmarkColor: accent,
      side: BorderSide(
        color: (selected ? accent : scheme.onSurfaceVariant).withValues(
          alpha: 0.5,
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.time,
    required this.selected,
    required this.taken,
    required this.accent,
    required this.onTap,
  });

  final String time;
  final bool selected;
  final bool taken;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected && !taken,
      onSelected: onTap == null ? null : (_) => onTap!(),
      label: Text(
        taken ? '$time · 예약됨' : time,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: taken
              ? scheme.onSurface.withValues(alpha: 0.45)
              : selected
              ? accent
              : scheme.onSurface,
        ),
      ),
      selectedColor: accent.withValues(alpha: 0.16),
      checkmarkColor: accent,
      side: BorderSide(
        color: (taken
                ? scheme.outline
                : selected
                ? accent
                : scheme.onSurfaceVariant)
            .withValues(alpha: 0.5),
      ),
    );
  }
}
