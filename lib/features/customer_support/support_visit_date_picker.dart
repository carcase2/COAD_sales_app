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

String _supportVisitScheduleLine({
  required String ymd,
  required String time,
  required String teamLabel,
}) {
  final day = ymd.trim().length >= 10 ? formatYmdFlowLabelKo(ymd.trim()) : ymd.trim();
  final t = normalizeSupportVisitTime(time);
  final team = teamLabel.trim();
  final parts = <String>[
    if (day.isNotEmpty) day,
    if (t.isNotEmpty) t,
    if (team.isNotEmpty) team,
  ];
  return parts.isEmpty ? '(미정)' : parts.join(' · ');
}

/// 일정 변경 확인. 확인이면 true.
Future<bool> confirmSupportVisitScheduleChange(
  BuildContext context, {
  required String fromYmd,
  required String fromTime,
  required String fromTeamLabel,
  required String toYmd,
  required String toTime,
  required String toTeamLabel,
}) async {
  final from = _supportVisitScheduleLine(
    ymd: fromYmd,
    time: fromTime,
    teamLabel: fromTeamLabel,
  );
  final to = _supportVisitScheduleLine(
    ymd: toYmd,
    time: toTime,
    teamLabel: toTeamLabel,
  );
  if (from == to) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('일정 변경 확인'),
        content: Text(
          '이전: $from\n변경: $to\n\n이대로 변경할까요?',
          style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('변경'),
          ),
        ],
      );
    },
  );
  return ok == true;
}

Future<SupportVisitPickResult?> showSupportVisitDatePicker(
  BuildContext context, {
  required SupportCallLog log,
  String? selectedYmd,
  String? selectedTeamId,
  String? selectedTime,
  String? selectedTeamLabel,
  /// 기존 일정이 있을 때 선택 후 확인 창을 띄운다.
  bool confirmChange = false,
}) async {
  final picked = await showModalBottomSheet<SupportVisitPickResult>(
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
  if (picked == null) return null;
  if (!confirmChange) return picked;
  final fromYmd = (selectedYmd ?? log.visitDate ?? '').trim();
  if (fromYmd.isEmpty) return picked;
  if (!context.mounted) return null;
  final fromTime = normalizeSupportVisitTime(
    selectedTime ?? log.visitTime,
  );
  final fromTeam = (selectedTeamLabel ?? '').trim().isNotEmpty
      ? selectedTeamLabel!.trim()
      : ((selectedTeamId ?? log.visitTeamId ?? '').trim().isEmpty
            ? '(팀 미정)'
            : '배정팀');
  final toTeam = (picked.teamLabel ?? '').trim().isEmpty
      ? '배정팀'
      : picked.teamLabel!.trim();
  final ok = await confirmSupportVisitScheduleChange(
    context,
    fromYmd: fromYmd,
    fromTime: fromTime,
    fromTeamLabel: fromTeam,
    toYmd: picked.ymd,
    toTime: picked.time,
    toTeamLabel: toTeam,
  );
  return ok ? picked : null;
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
  /// null이면 주간표에 지사 팀 전체. 값이 있으면 그 팀만.
  String? _filterTeamId;
  String? _time;
  String _branch = '본사';
  bool _branchReady = false;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  List<SupportAsVisitTeam> _teams = const [];
  Map<String, SupportVisitDayBookings> _bookings = const {};
  bool _loading = true;
  Object? _error;

  static const _branchChoices = ['본사', '대구', '대전', '전남', '기타'];

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
    // 주간표는 전체(팀별 색)로 시작하고, 칩으로 자기 팀만 좁힌다.
    _filterTeamId = null;
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

  String get _addressBranch {
    final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];
    return matchSupportBranchType(widget.log.address ?? '', regions);
  }

  int get _slotCap => supportVisitDaySlotCapacity(_teams.length);

  Iterable<String> get _teamIds => _teams.map((t) => t.id);

  SupportVisitDayBookings _dayBookings(String ymd) =>
      _bookings[ymd] ?? const SupportVisitDayBookings();

  bool _isFutureOrToday(DateTime day) {
    final today = _fromYmd(todayYmdSeoul());
    final start = DateTime(today.year, today.month, today.day);
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start);
  }

  bool _isOpen(DateTime day) {
    if (!_isFutureOrToday(day)) return false;
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
      final weekStart = seoulWeekRangeContaining(
        supportVisitWeekFocusYmd(today),
      ).$1;
      final fromYmd = weekStart.compareTo(today) < 0 ? weekStart : today;
      final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];
      final repo = ref.read(supportAsVisitTeamRepositoryProvider);
      if (!_branchReady) {
        var branch = _addressBranch;
        final preferTeam = (_teamId ?? '').trim();
        if (preferTeam.isNotEmpty) {
          final all = await repo.list(activeOnly: true);
          for (final t in all) {
            if (t.id == preferTeam && t.branch.trim().isNotEmpty) {
              branch = t.branch.trim();
              break;
            }
          }
        }
        if (!_branchChoices.contains(branch)) branch = '기타';
        _branch = branch;
        _branchReady = true;
      }
      final teams = await repo.listForBranch(_branch, activeOnly: true);
      final bookings = await ref
          .read(supportCallLogRepositoryProvider)
          .listScheduledVisitsByYmd(
            fromYmd: fromYmd,
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
        if (_teamId == null || !_teams.any((t) => t.id == _teamId)) {
          _teamId = _teams.isEmpty ? null : _teams.first.id;
        }
        if (_filterTeamId != null &&
            !_teams.any((t) => t.id == _filterTeamId)) {
          _filterTeamId = null;
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

  Future<void> _openDaySheet(
    DateTime day, {
    String? preferTeamId,
    String? preferTime,
  }) async {
    if (!_isFutureOrToday(day)) return;
    final ymd = _toYmd(day);
    setState(() {
      _selected = day;
      _focused = day;
    });
    final picked = await showModalBottomSheet<SupportVisitPickResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      builder: (_) => _SupportVisitDaySlotSheet(
        log: widget.log,
        ymd: ymd,
        initialBranch: _branch,
        initialTeamId: preferTeamId ?? _teamId,
        initialTime: preferTime ?? _time,
      ),
    );
    if (!mounted) return;
    if (picked == null) return;
    Navigator.of(context).pop(picked);
  }

  Future<void> _pickSlotDirect({
    required String ymd,
    required String teamId,
    required String time,
  }) async {
    if (ymd.compareTo(todayYmdSeoul()) < 0) return;
    SupportAsVisitTeam? team;
    for (final t in _teams) {
      if (t.id == teamId) {
        team = t;
        break;
      }
    }
    if (team == null) return;
    if (_dayBookings(ymd).teamTimeTaken(teamId: teamId, time: time)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$time 은 이미 예약되어 있습니다.')),
      );
      return;
    }
    Navigator.of(context).pop(
      SupportVisitPickResult(
        ymd: ymd,
        teamId: teamId,
        time: time,
        teamLabel: team.label,
      ),
    );
  }

  void _selectBranch(String branch) {
    if (_branch == branch) return;
    setState(() {
      _branch = branch;
      _teamId = null;
      _time = null;
    });
    unawaited(_load());
  }

  Future<void> _pickEarliest() async {
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
    await _openDaySheet(_fromYmd(ymd));
  }

  String get _weekAnchorYmd =>
      supportVisitWeekFocusYmd(_toYmd(_focused));

  @override
  Widget build(BuildContext context) {
    ref.listen(regionsRawProvider, (prev, next) {
      if (next.hasValue) unawaited(_load());
    });
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;
    final height = media.size.height * 0.88;
    final isWeek = _calendarFormat == CalendarFormat.week;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '방문예정일',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _loading || _slotCap <= 0 ? null : _pickEarliest,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 16),
                  label: const Text(
                    '가장 빠른 날',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                if (isWeek) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      final today = supportVisitWeekFocusYmd(todayYmdSeoul());
                      setState(() {
                        _focused = _fromYmd(today);
                        _selected = _focused;
                      });
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      '오늘',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                _FormatToggle(
                  format: _calendarFormat,
                  accent: accent,
                  onChanged: (format) {
                    if (_calendarFormat == format) return;
                    setState(() {
                      _calendarFormat = format;
                      if (_selected != null) _focused = _selected!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _branchChoices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final b = _branchChoices[i];
                  final selected = _branch == b;
                  final color = AppTokens.supportBranchAccent(b, scheme);
                  return FilterChip(
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    onSelected: _loading ? null : (_) => _selectBranch(b),
                    label: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? color : scheme.onSurface,
                      ),
                    ),
                    selectedColor: color.withValues(alpha: 0.16),
                    checkmarkColor: color,
                    showCheckmark: false,
                    side: BorderSide(
                      color: (selected ? color : scheme.onSurfaceVariant)
                          .withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  koreanErrorMessage(_error!),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 6),
            if (isWeek && _teams.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('전체'),
                        selected: _filterTeamId == null,
                        visualDensity: VisualDensity.compact,
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _filterTeamId = null),
                      ),
                    ),
                    for (var i = 0; i < _teams.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: supportVisitTeamColor(
                              _teams[i].id,
                              index: i,
                            ),
                            radius: 8,
                          ),
                          label: Text(_teams[i].name.trim().isEmpty
                              ? _teams[i].label
                              : _teams[i].name.trim()),
                          selected: _filterTeamId == _teams[i].id,
                          visualDensity: VisualDensity.compact,
                          selectedColor: supportVisitTeamColor(
                            _teams[i].id,
                            index: i,
                          ).withValues(alpha: 0.22),
                          onSelected: _loading
                              ? null
                              : (_) => setState(() {
                                  _filterTeamId = _teams[i].id;
                                  _teamId = _teams[i].id;
                                }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: isWeek
                  ? _PickerWeekGrid(
                      anchorYmd: _weekAnchorYmd,
                      selectedYmd: _selected == null
                          ? null
                          : _toYmd(_selected!),
                      filterTeamId: _filterTeamId,
                      teams: _teams,
                      bookings: _bookings,
                      onWeekChanged: (mondayYmd) {
                        setState(() => _focused = _fromYmd(mondayYmd));
                      },
                      onDaySelected: (ymd) {
                        unawaited(_openDaySheet(_fromYmd(ymd)));
                      },
                      onEmptySlot: (ymd, time, teamId) {
                        unawaited(
                          _pickSlotDirect(
                            ymd: ymd,
                            teamId: teamId,
                            time: time,
                          ),
                        );
                      },
                      onFilledSlot: (ymd, time, teamId) {
                        unawaited(
                          _openDaySheet(
                            _fromYmd(ymd),
                            preferTeamId: teamId,
                            preferTime: time,
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      child: TableCalendar<void>(
                        locale: 'ko_KR',
                        firstDay: _fromYmd(todayYmdSeoul()),
                        lastDay: _fromYmd(addDaysToYmd(todayYmdSeoul(), 120)),
                        focusedDay: _focused,
                        selectedDayPredicate: (d) =>
                            _selected != null && isSameDay(d, _selected),
                        enabledDayPredicate: _isFutureOrToday,
                        calendarFormat: CalendarFormat.month,
                        availableCalendarFormats: const {
                          CalendarFormat.month: '월간',
                        },
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        rowHeight: 44,
                        daysOfWeekHeight: 24,
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          headerPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onDaySelected: (selected, focused) {
                          setState(() => _focused = focused);
                          unawaited(_openDaySheet(selected));
                        },
                        onPageChanged: (focused) =>
                            setState(() => _focused = focused),
                        calendarBuilders: CalendarBuilders(
                          dowBuilder: (context, day) {
                            final weekend =
                                supportVisitWeekendDayColor(day.weekday);
                            return Center(
                              child: Text(
                                switch (day.weekday) {
                                  DateTime.monday => '월',
                                  DateTime.tuesday => '화',
                                  DateTime.wednesday => '수',
                                  DateTime.thursday => '목',
                                  DateTime.friday => '금',
                                  DateTime.saturday => '토',
                                  DateTime.sunday => '일',
                                  _ => '',
                                },
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: weekend ?? scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
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
                            today: _toYmd(day) == todayYmdSeoul(),
                          ),
                          disabledBuilder: (context, day, focused) => _cell(
                            day,
                            scheme: scheme,
                            accent: accent,
                            disabled: true,
                          ),
                        ),
                      ),
                    ),
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
    final isToday = today || ymd == todayYmdSeoul();
    final booked = _dayBookings(ymd).totalCount;
    final open = !disabled && _isOpen(day);
    final weekend = supportVisitWeekendDayColor(day.weekday);
    final Color fg;
    if (selected) {
      fg = Colors.white;
    } else if (disabled) {
      fg = (weekend ?? scheme.onSurface).withValues(alpha: 0.35);
    } else if (weekend != null) {
      fg = weekend;
    } else {
      fg = scheme.onSurface;
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
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: fg,
              ),
            ),
            Text(
              _slotCap <= 0 ? '-' : '$booked',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : open
                    ? (weekend ?? accent)
                    : scheme.error.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 본사일반 주간달력 레이아웃 + 시간칸을 팀별 색으로 표시.
class _PickerWeekGrid extends StatefulWidget {
  const _PickerWeekGrid({
    required this.anchorYmd,
    required this.bookings,
    required this.teams,
    required this.onWeekChanged,
    required this.onDaySelected,
    required this.onEmptySlot,
    required this.onFilledSlot,
    this.selectedYmd,
    this.filterTeamId,
  });

  final String anchorYmd;
  final String? selectedYmd;
  /// null이면 전체 팀, 아니면 해당 팀만.
  final String? filterTeamId;
  final List<SupportAsVisitTeam> teams;
  final Map<String, SupportVisitDayBookings> bookings;
  final ValueChanged<String> onWeekChanged;
  final ValueChanged<String> onDaySelected;
  final void Function(String ymd, String time, String teamId) onEmptySlot;
  final void Function(String ymd, String time, String teamId) onFilledSlot;

  static const weekPageCount = 105;
  static const centerIndex = 52;

  @override
  State<_PickerWeekGrid> createState() => _PickerWeekGridState();
}

class _PickerWeekGridState extends State<_PickerWeekGrid> {
  late final PageController _pageController;
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _PickerWeekGrid.centerIndex);
  }

  @override
  void didUpdateWidget(covariant _PickerWeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorYmd == widget.anchorYmd) return;
    final oldMonday = seoulWeekRangeContaining(oldWidget.anchorYmd).$1;
    final newMonday = seoulWeekRangeContaining(widget.anchorYmd).$1;
    if (oldMonday == newMonday) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCenter());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpToCenter() {
    if (!_pageController.hasClients) return;
    _programmaticPage = true;
    _pageController.jumpToPage(_PickerWeekGrid.centerIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _programmaticPage = false;
    });
  }

  List<String> _weekMondays() {
    final monday = seoulWeekRangeContaining(widget.anchorYmd).$1;
    return List.generate(
      _PickerWeekGrid.weekPageCount,
      (i) => addDaysToYmd(
        monday,
        (i - _PickerWeekGrid.centerIndex) * 7,
      ),
    );
  }

  int _weekdayOffset(String ymd) {
    final monday = seoulWeekRangeContaining(ymd).$1;
    final partsY = ymd.split('-');
    final partsM = monday.split('-');
    if (partsY.length != 3 || partsM.length != 3) return 0;
    final a = DateTime(
      int.parse(partsY[0]),
      int.parse(partsY[1]),
      int.parse(partsY[2]),
    );
    final b = DateTime(
      int.parse(partsM[0]),
      int.parse(partsM[1]),
      int.parse(partsM[2]),
    );
    return a.difference(b).inDays.clamp(0, 6);
  }

  void _onPageChanged(int index) {
    if (_programmaticPage) return;
    if (index < 0 || index >= _PickerWeekGrid.weekPageCount) return;
    final mondays = _weekMondays();
    if (index >= mondays.length) return;
    final target = addDaysToYmd(
      mondays[index],
      _weekdayOffset(widget.anchorYmd),
    );
    if (target == widget.anchorYmd) return;
    widget.onWeekChanged(seoulWeekRangeContaining(target).$1);
  }

  List<SupportAsVisitTeam> get _visibleTeams {
    final filter = (widget.filterTeamId ?? '').trim();
    if (filter.isEmpty) return widget.teams;
    return widget.teams.where((t) => t.id == filter).toList();
  }

  Color _colorFor(SupportAsVisitTeam team) {
    final i = widget.teams.indexWhere((t) => t.id == team.id);
    return supportVisitTeamColor(team.id, index: i < 0 ? null : i);
  }

  bool _taken(String ymd, String teamId, String time) {
    final day = widget.bookings[ymd] ?? const SupportVisitDayBookings();
    return day.teamTimeTaken(teamId: teamId, time: time);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teams.isEmpty) {
      return const Center(
        child: Text(
          '이 지사에 등록된 팀이 없습니다',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    final mondays = _weekMondays();
    final visible = _visibleTeams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            SupportVisitWeekTimeGutterHeader(),
            Expanded(child: SupportVisitWeekdayHeaderRow()),
          ],
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: mondays.length,
            itemBuilder: (context, index) {
              final days = List.generate(
                kSupportVisitWeekdayColumnCount,
                (i) => addDaysToYmd(mondays[index], i),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SupportVisitWeekTimeGutter(
                    monthLabel: supportVisitWeekMonthLabel(days),
                  ),
                  Expanded(
                    child: _PickerWeekTable(
                      days: days,
                      selectedYmd: widget.selectedYmd,
                      visibleTeams: visible,
                      colorForTeam: _colorFor,
                      isTaken: _taken,
                      onDaySelected: widget.onDaySelected,
                      onEmptySlot: widget.onEmptySlot,
                      onFilledSlot: widget.onFilledSlot,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PickerWeekTable extends StatelessWidget {
  const _PickerWeekTable({
    required this.days,
    required this.visibleTeams,
    required this.colorForTeam,
    required this.isTaken,
    required this.onDaySelected,
    required this.onEmptySlot,
    required this.onFilledSlot,
    this.selectedYmd,
  });

  final List<String> days;
  final String? selectedYmd;
  final List<SupportAsVisitTeam> visibleTeams;
  final Color Function(SupportAsVisitTeam team) colorForTeam;
  final bool Function(String ymd, String teamId, String time) isTaken;
  final ValueChanged<String> onDaySelected;
  final void Function(String ymd, String time, String teamId) onEmptySlot;
  final void Function(String ymd, String time, String teamId) onFilledSlot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < kSupportVisitWeekdayColumnCount; i++)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: days[i] == todayYmdSeoul()
                        ? const Color(0xFFEFF6FF)
                        : kSupportVisitWeekdayStyles[i].columnBg,
                    border: supportVisitWeekDayColumnBorder(
                      isToday: days[i] == todayYmdSeoul(),
                      showRightDivider: i < kSupportVisitWeekdayColumnCount - 1,
                    ),
                  ),
                  child: _PickerWeekDayColumn(
                    ymd: days[i],
                    style: kSupportVisitWeekdayStyles[i],
                    selected: days[i] == selectedYmd,
                    visibleTeams: visibleTeams,
                    colorForTeam: colorForTeam,
                    isTaken: isTaken,
                    onDaySelected: onDaySelected,
                    onEmptySlot: onEmptySlot,
                    onFilledSlot: onFilledSlot,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerWeekDayColumn extends StatelessWidget {
  const _PickerWeekDayColumn({
    required this.ymd,
    required this.style,
    required this.selected,
    required this.visibleTeams,
    required this.colorForTeam,
    required this.isTaken,
    required this.onDaySelected,
    required this.onEmptySlot,
    required this.onFilledSlot,
  });

  final String ymd;
  final SupportVisitWeekdayStyle style;
  final bool selected;
  final List<SupportAsVisitTeam> visibleTeams;
  final Color Function(SupportAsVisitTeam team) colorForTeam;
  final bool Function(String ymd, String teamId, String time) isTaken;
  final ValueChanged<String> onDaySelected;
  final void Function(String ymd, String time, String teamId) onEmptySlot;
  final void Function(String ymd, String time, String teamId) onFilledSlot;

  @override
  Widget build(BuildContext context) {
    final today = todayYmdSeoul();
    final past = ymd.compareTo(today) < 0;
    final slotCount = kSupportVisitTimeSlots.length;
    var free = 0;
    for (final time in kSupportVisitTimeSlots) {
      for (final team in visibleTeams) {
        if (!isTaken(ymd, team.id, time)) free += 1;
      }
    }
    final isFull = !past && visibleTeams.isNotEmpty && free == 0;
    final dayNum = int.tryParse(ymd.split('-').last) ?? 0;

    return Column(
      children: [
        SupportVisitWeekDayBadge(
          dayNum: dayNum,
          dateFg: style.dateFg,
          selected: selected,
          isFull: isFull,
          past: past,
          onTap: past ? null : () => onDaySelected(ymd),
        ),
        for (var i = 0; i < slotCount; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                1.5,
                i == 0 ? 1.5 : 1,
                1.5,
                i == slotCount - 1 ? 1.5 : 0,
              ),
              child: _PickerWeekTimeRow(
                ymd: ymd,
                time: kSupportVisitTimeSlots[i],
                past: past,
                visibleTeams: visibleTeams,
                colorForTeam: colorForTeam,
                isTaken: isTaken,
                onEmptySlot: onEmptySlot,
                onFilledSlot: onFilledSlot,
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerWeekTimeRow extends StatelessWidget {
  const _PickerWeekTimeRow({
    required this.ymd,
    required this.time,
    required this.past,
    required this.visibleTeams,
    required this.colorForTeam,
    required this.isTaken,
    required this.onEmptySlot,
    required this.onFilledSlot,
  });

  final String ymd;
  final String time;
  final bool past;
  final List<SupportAsVisitTeam> visibleTeams;
  final Color Function(SupportAsVisitTeam team) colorForTeam;
  final bool Function(String ymd, String teamId, String time) isTaken;
  final void Function(String ymd, String time, String teamId) onEmptySlot;
  final void Function(String ymd, String time, String teamId) onFilledSlot;

  String _short(SupportAsVisitTeam team) {
    final n = team.name.trim();
    if (n.isNotEmpty) {
      return n.length <= 2 ? n : n.substring(0, 2);
    }
    final label = team.label.trim();
    if (label.isEmpty) return '팀';
    return label.length <= 2 ? label : label.substring(0, 2);
  }

  VoidCallback? _tap({
    required bool taken,
    required String teamId,
  }) {
    if (past) return null;
    return () {
      if (taken) {
        onFilledSlot(ymd, time, teamId);
      } else {
        onEmptySlot(ymd, time, teamId);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (visibleTeams.isEmpty) return const SizedBox.expand();
    if (visibleTeams.length == 1) {
      final team = visibleTeams.first;
      final taken = isTaken(ymd, team.id, time);
      return _PickerWeekSlotBar(
        label: taken ? _short(team) : '',
        taken: taken,
        past: past,
        barColor: colorForTeam(team),
        onTap: _tap(taken: taken, teamId: team.id),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < visibleTeams.length; i++) ...[
          if (i > 0) const SizedBox(width: 1.5),
          Expanded(
            child: Builder(
              builder: (context) {
                final team = visibleTeams[i];
                final taken = isTaken(ymd, team.id, time);
                return _PickerWeekSlotBar(
                  label: taken ? _short(team) : '',
                  taken: taken,
                  past: past,
                  barColor: colorForTeam(team),
                  onTap: _tap(taken: taken, teamId: team.id),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PickerWeekSlotBar extends StatelessWidget {
  const _PickerWeekSlotBar({
    required this.label,
    required this.taken,
    required this.past,
    required this.barColor,
    required this.onTap,
  });

  final String label;
  final bool taken;
  final bool past;
  final Color barColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = taken
        ? (past ? barColor.withValues(alpha: 0.45) : barColor)
        : const Color(0xFFFFFFFF);
    final borderColor = taken
        ? Color.lerp(fill, const Color(0xFF111827), 0.38)!
        : past
        ? const Color(0xFFD1D5DB)
        : Color.lerp(barColor, const Color(0xFF6B7280), 0.35)!;
    const radius = BorderRadius.all(Radius.circular(4));

    return Material(
      color: fill,
      elevation: taken && !past ? 0.6 : 0,
      shadowColor: taken ? Colors.black26 : Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: taken ? 1.3 : 1.1,
            ),
          ),
          child: taken
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: past ? 0.7 : 1),
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 1.4),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 날짜 탭 후: 지사 · 팀 · 시간. 이미 예약된 시간은 표시만 하고 고를 수 없음.
class _SupportVisitDaySlotSheet extends ConsumerStatefulWidget {
  const _SupportVisitDaySlotSheet({
    required this.log,
    required this.ymd,
    required this.initialBranch,
    this.initialTeamId,
    this.initialTime,
  });

  final SupportCallLog log;
  final String ymd;
  final String initialBranch;
  final String? initialTeamId;
  final String? initialTime;

  @override
  ConsumerState<_SupportVisitDaySlotSheet> createState() =>
      _SupportVisitDaySlotSheetState();
}

class _SupportVisitDaySlotSheetState
    extends ConsumerState<_SupportVisitDaySlotSheet> {
  static const _branchChoices = ['본사', '대구', '대전', '전남', '기타'];

  late String _branch;
  String? _teamId;
  String? _time;
  List<SupportAsVisitTeam> _teams = const [];
  SupportVisitDayBookings _bookings = const SupportVisitDayBookings();
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _branch = _branchChoices.contains(widget.initialBranch)
        ? widget.initialBranch
        : '본사';
    _teamId = (widget.initialTeamId ?? '').trim().isEmpty
        ? null
        : widget.initialTeamId!.trim();
    final t = normalizeSupportVisitTime(widget.initialTime);
    _time = t.isEmpty ? null : t;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final regions = ref.read(regionsRawProvider).valueOrNull ?? const [];
      final teams = await ref
          .read(supportAsVisitTeamRepositoryProvider)
          .listForBranch(_branch, activeOnly: true);
      final byDay = await ref
          .read(supportCallLogRepositoryProvider)
          .listScheduledVisitsByYmd(
            fromYmd: widget.ymd,
            toYmdInclusive: widget.ymd,
            branch: _branch,
            regions: regions,
            excludeLogId: widget.log.id,
          );
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _bookings = byDay[widget.ymd] ?? const SupportVisitDayBookings();
        _loading = false;
        if (_teamId == null || !_teams.any((t) => t.id == _teamId)) {
          _teamId = _teams.isEmpty ? null : _teams.first.id;
        }
        if (_teamId != null) {
          final free = supportVisitFreeTimesForTeam(
            teamId: _teamId!,
            bookings: _bookings,
          );
          if (_time == null || !free.contains(_time)) {
            _time = free.isEmpty ? null : free.first;
          }
        } else {
          _time = null;
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

  void _selectBranch(String branch) {
    if (_branch == branch) return;
    setState(() {
      _branch = branch;
      _teamId = null;
      _time = null;
    });
    unawaited(_load());
  }

  List<({String teamLabel, String time})> get _takenSlots {
    final out = <({String teamLabel, String time})>[];
    for (final team in _teams) {
      final times = _bookings.timesForTeam(team.id).toList()..sort();
      for (final t in times) {
        out.add((teamLabel: team.label, time: t));
      }
    }
    out.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      if (byTime != 0) return byTime;
      return a.teamLabel.compareTo(b.teamLabel);
    });
    return out;
  }

  void _confirm() {
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
    if (!supportVisitTeamTimeFree(
      teamId: teamId,
      time: time,
      bookings: _bookings,
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
        ymd: widget.ymd,
        teamId: teamId,
        time: time,
        teamLabel: team?.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;
    final taken = _takenSlots;
    final ymdLabel = widget.ymd;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ymdLabel,
              maxLines: 1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '방문 지사',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _branchChoices.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final b = _branchChoices[i];
                  final selected = _branch == b;
                  final color = AppTokens.supportBranchAccent(b, scheme);
                  return FilterChip(
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    onSelected: _loading ? null : (_) => _selectBranch(b),
                    label: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? color : scheme.onSurface,
                      ),
                    ),
                    selectedColor: color.withValues(alpha: 0.16),
                    checkmarkColor: color,
                    showCheckmark: false,
                    side: BorderSide(
                      color: (selected ? color : scheme.onSurfaceVariant)
                          .withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  koreanErrorMessage(_error!),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (taken.isNotEmpty) ...[
                      Text(
                        '이미 예약된 시간',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final slot in taken)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${slot.time} · ${slot.teamLabel} · 선택 불가',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      '$_branch 방문 팀',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!_loading && _teams.isEmpty)
                      Text(
                        '$_branch에 등록된 팀이 없습니다',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.error,
                        ),
                      ),
                    if (_teams.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final team in _teams)
                            _TeamChip(
                              team: team,
                              selected: _teamId == team.id,
                              visitCount: _bookings.visitsForTeam(team.id),
                              accent: accent,
                              onTap: () => setState(() {
                                _teamId = team.id;
                                final free = supportVisitFreeTimesForTeam(
                                  teamId: team.id,
                                  bookings: _bookings,
                                );
                                if (_time == null || !free.contains(_time)) {
                                  _time = free.isEmpty ? null : free.first;
                                }
                              }),
                            ),
                        ],
                      ),
                    if ((_teamId ?? '').isNotEmpty) ...[
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
                              taken: _bookings.teamTimeTaken(
                                teamId: _teamId!,
                                time: slot,
                              ),
                              accent: accent,
                              onTap: _bookings.teamTimeTaken(
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
              onPressed: _loading || _teams.isEmpty ? null : _confirm,
              child: const Text('이 지사·팀·시간으로 선택'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatToggle extends StatelessWidget {
  const _FormatToggle({
    required this.format,
    required this.accent,
    required this.onChanged,
  });

  final CalendarFormat format;
  final Color accent;
  final ValueChanged<CalendarFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, CalendarFormat value) {
      final selected = format == value;
      return Material(
        color: selected
            ? accent.withValues(alpha: 0.16)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: selected ? accent : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip('주간', CalendarFormat.week),
        const SizedBox(width: 6),
        chip('월간', CalendarFormat.month),
      ],
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
