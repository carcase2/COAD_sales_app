import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_schedule_filters.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_date_picker.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 본사일반 주간달력과 같은 레이아웃 — 월~금 5열 × 시간 슬롯.
class SupportVisitWeekBoard extends ConsumerStatefulWidget {
  const SupportVisitWeekBoard({
    super.key,
    required this.anchorYmd,
    required this.events,
    required this.teams,
    required this.onReload,
    this.onAnchorChanged,
    this.branch = '전체',
  });

  final String anchorYmd;
  final List<SupportScheduleEvent> events;
  final List<SupportAsVisitTeam> teams;
  final Future<void> Function() onReload;
  final ValueChanged<String>? onAnchorChanged;
  final String branch;

  static const weekPageCount = 105;
  static const centerIndex = 52;

  @override
  ConsumerState<SupportVisitWeekBoard> createState() =>
      _SupportVisitWeekBoardState();
}

class _SupportVisitWeekBoardState extends ConsumerState<SupportVisitWeekBoard> {
  /// null = 전체 팀.
  String? _teamId;
  late final PageController _pageController;
  bool _programmaticPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: SupportVisitWeekBoard.centerIndex,
    );
    _teamId = null;
  }

  @override
  void didUpdateWidget(covariant SupportVisitWeekBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final teams = _teams;
    if (_teamId != null &&
        (teams.isEmpty || !teams.any((t) => t.id == _teamId))) {
      _teamId = null;
    }
    if (oldWidget.anchorYmd != widget.anchorYmd) {
      final oldMonday =
          seoulWeekRangeContaining(oldWidget.anchorYmd).$1;
      final newMonday = seoulWeekRangeContaining(widget.anchorYmd).$1;
      if (oldMonday != newMonday) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCenter());
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<SupportAsVisitTeam> get _teams {
    final all = widget.teams.where((t) => t.active).toList();
    if (widget.branch == '전체') return all;
    return all.where((t) => t.branch == widget.branch).toList();
  }

  List<SupportScheduleEvent> get _visits {
    var rows = supportHomeCalendarEvents(
      widget.events,
      kind: SupportHomeCalendarKind.visit,
    );
    final teamId = _teamId;
    if (teamId != null) {
      rows = rows.where((e) => (e.log.visitTeamId ?? '') == teamId).toList();
    }
    return rows;
  }

  SupportAsVisitTeam? get _selectedTeam {
    final teams = _teams;
    if (teams.isEmpty) return null;
    final id = _teamId;
    if (id == null) return null;
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return teams.first;
  }

  SupportAsVisitTeam? _teamById(String? id) {
    final key = (id ?? '').trim();
    if (key.isEmpty) return null;
    for (final t in _teams) {
      if (t.id == key) return t;
    }
    for (final t in widget.teams) {
      if (t.id == key) return t;
    }
    return null;
  }

  void _jumpToCenter() {
    if (!_pageController.hasClients) return;
    _programmaticPage = true;
    _pageController.jumpToPage(SupportVisitWeekBoard.centerIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _programmaticPage = false;
    });
  }

  List<String> _weekMondays() {
    final monday = seoulWeekRangeContaining(widget.anchorYmd).$1;
    return List.generate(
      SupportVisitWeekBoard.weekPageCount,
      (i) => addDaysToYmd(
        monday,
        (i - SupportVisitWeekBoard.centerIndex) * 7,
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
    if (index < 0 || index >= SupportVisitWeekBoard.weekPageCount) return;
    final mondays = _weekMondays();
    if (index >= mondays.length) return;
    final target = addDaysToYmd(
      mondays[index],
      _weekdayOffset(widget.anchorYmd).clamp(0, 4),
    );
    if (target == widget.anchorYmd) return;
    HapticFeedback.selectionClick();
    widget.onAnchorChanged?.call(target);
  }

  SupportScheduleEvent? _at(String ymd, String time, String? teamId) {
    for (final e in _visits) {
      if (e.ymd != ymd) continue;
      if (teamId != null && (e.log.visitTeamId ?? '') != teamId) continue;
      final t = normalizeSupportVisitTime(e.scheduledTime ?? e.log.visitTime);
      if (t == time) return e;
    }
    return null;
  }

  Color _barColorFor(SupportScheduleEvent? e, SupportAsVisitTeam? fallback) {
    final team = _teamById(e?.log.visitTeamId) ?? fallback;
    if (team != null) return _teamBarColor(team);
    return const Color(0xFF2563EB);
  }

  String _site(SupportCallLog log) {
    final site = parseSupportIssueBody(log.issue).siteName.trim();
    if (site.isNotEmpty) return site;
    final name = log.customerName.trim();
    return name.isEmpty ? '(현장 없음)' : name;
  }

  Color _teamBarColor(SupportAsVisitTeam team) {
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF0D9488),
      Color(0xFFEA580C),
      Color(0xFF4F46E5),
    ];
    final i = team.id.hashCode.abs() % palette.length;
    return palette[i];
  }

  Future<void> _onEmpty({
    required String ymd,
    required String time,
    required SupportAsVisitTeam team,
  }) async {
    final log = await _pickIncompleteLog();
    if (log == null || !mounted) return;
    try {
      await ref
          .read(supportCallLogRepositoryProvider)
          .updateVisitSchedule(
            callLogId: log.id,
            visitYmd: ymd,
            visitTeamId: team.id,
            visitTime: time,
          );
      invalidateSupportWorkCaches(ref);
      unawaited(refreshSupportDueReminders(ref));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_site(log)} · $ymd $time ${team.label}')),
        );
      }
      await widget.onReload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<SupportCallLog?> _pickIncompleteLog() async {
    final rows = await ref
        .read(supportCallLogRepositoryProvider)
        .list(incompleteOnly: true, limit: 200);
    if (!mounted) return null;
    return showModalBottomSheet<SupportCallLog>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final q = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final query = q.text.trim().toLowerCase();
            final visible = rows.where((e) {
              if (query.isEmpty) return true;
              final blob = [
                e.customerName,
                e.customerPhone,
                e.address ?? '',
                e.issue,
              ].join(' ').toLowerCase();
              return blob.contains(query);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '방문할 현장',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: q,
                        decoration: const InputDecoration(
                          hintText: '이름 · 전화 · 주소',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setLocal(() {}),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final log = visible[i];
                            return ListTile(
                              title: Text(
                                _site(log),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if ((log.visitDate ?? '').isNotEmpty)
                                    '현재 ${log.visitDate} ${log.visitTime ?? ''}',
                                  log.customerPhone,
                                ].join(' · '),
                              ),
                              onTap: () => Navigator.pop(ctx, log),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onFilled(SupportScheduleEvent e) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    _site(e.log),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${e.ymd} ${normalizeSupportVisitTime(e.scheduledTime ?? e.log.visitTime)}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('접수 상세'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CustomerSupportReceptionDetailScreen(log: e.log),
                      ),
                    );
                    await widget.onReload();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_calendar_rounded,
                    color: scheme.tertiary,
                  ),
                  title: const Text('일정 변경'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await showSupportVisitDatePicker(
                      context,
                      log: e.log,
                      selectedYmd: e.log.visitDate,
                      selectedTeamId: e.log.visitTeamId,
                      selectedTime: e.log.visitTime,
                      selectedTeamLabel:
                          _teamById(e.log.visitTeamId)?.label,
                      confirmChange: true,
                    );
                    if (picked == null) return;
                    await ref
                        .read(supportCallLogRepositoryProvider)
                        .updateVisitSchedule(
                          callLogId: e.log.id,
                          visitYmd: picked.ymd,
                          visitTeamId: picked.teamId,
                          visitTime: picked.time,
                        );
                    invalidateSupportWorkCaches(ref);
                    unawaited(refreshSupportDueReminders(ref));
                    await widget.onReload();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.home_repair_service_outlined),
                  title: const Text('방문 기록'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await showSupportVisitReportSheet(context, log: e.log);
                    await widget.onReload();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = _teams;
    if (teams.isEmpty) {
      return const Center(child: Text('이 지사에 방문 팀이 없습니다.'));
    }
    final selectedTeam = _selectedTeam;
    final bookingTeam = selectedTeam ?? teams.first;
    final mondays = _weekMondays();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('전체'),
                  selected: _teamId == null,
                  onSelected: (_) => setState(() => _teamId = null),
                ),
              ),
              for (final t in teams)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: _teamId == t.id,
                    selectedColor: _teamBarColor(t).withValues(alpha: 0.22),
                    onSelected: (_) => setState(() => _teamId = t.id),
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Row(
            children: [
              SupportVisitWeekTimeGutterHeader(),
              Expanded(child: SupportVisitWeekdayHeaderRow()),
            ],
          ),
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
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SupportVisitWeekTimeGutter(
                      monthLabel: supportVisitWeekMonthLabel(days),
                    ),
                    Expanded(
                      child: _WeekTable(
                        days: days,
                        selectedYmd: widget.anchorYmd,
                        eventAt: (ymd, time) => _at(ymd, time, _teamId),
                        barColorOf: (e) => _barColorFor(e, bookingTeam),
                        siteOf: _site,
                        onDaySelected: (ymd) {
                          HapticFeedback.selectionClick();
                          widget.onAnchorChanged?.call(ymd);
                        },
                        onEmptyTap: (ymd, time) {
                          HapticFeedback.selectionClick();
                          unawaited(
                            _onEmpty(
                              ymd: ymd,
                              time: time,
                              team: bookingTeam,
                            ),
                          );
                        },
                        onFilledTap: (e) {
                          HapticFeedback.selectionClick();
                          unawaited(_onFilled(e));
                        },
                      ),
                    ),
                  ],
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

class _WeekTable extends StatelessWidget {
  const _WeekTable({
    required this.days,
    required this.selectedYmd,
    required this.eventAt,
    required this.barColorOf,
    required this.siteOf,
    required this.onDaySelected,
    required this.onEmptyTap,
    required this.onFilledTap,
  });

  final List<String> days;
  final String selectedYmd;
  final SupportScheduleEvent? Function(String ymd, String time) eventAt;
  final Color Function(SupportScheduleEvent? event) barColorOf;
  final String Function(SupportCallLog) siteOf;
  final ValueChanged<String> onDaySelected;
  final void Function(String ymd, String time) onEmptyTap;
  final ValueChanged<SupportScheduleEvent> onFilledTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(10),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(10),
        ),
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
                  child: _WeekDayColumn(
                    ymd: days[i],
                    style: kSupportVisitWeekdayStyles[i],
                    selected: days[i] == selectedYmd,
                    eventAt: eventAt,
                    barColorOf: barColorOf,
                    siteOf: siteOf,
                    onDaySelected: onDaySelected,
                    onEmptyTap: onEmptyTap,
                    onFilledTap: onFilledTap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.ymd,
    required this.style,
    required this.selected,
    required this.eventAt,
    required this.barColorOf,
    required this.siteOf,
    required this.onDaySelected,
    required this.onEmptyTap,
    required this.onFilledTap,
  });

  final String ymd;
  final SupportVisitWeekdayStyle style;
  final bool selected;
  final SupportScheduleEvent? Function(String ymd, String time) eventAt;
  final Color Function(SupportScheduleEvent? event) barColorOf;
  final String Function(SupportCallLog) siteOf;
  final ValueChanged<String> onDaySelected;
  final void Function(String ymd, String time) onEmptyTap;
  final ValueChanged<SupportScheduleEvent> onFilledTap;

  @override
  Widget build(BuildContext context) {
    final slotCount = kSupportVisitTimeSlots.length;
    var filledCount = 0;
    for (final time in kSupportVisitTimeSlots) {
      if (eventAt(ymd, time) != null) filledCount += 1;
    }
    final isFull = filledCount >= slotCount;
    final dayNum = int.tryParse(ymd.split('-').last) ?? 0;

    return Column(
      children: [
        SupportVisitWeekDayBadge(
          dayNum: dayNum,
          dateFg: style.dateFg,
          selected: selected,
          isFull: isFull,
          onTap: () => onDaySelected(ymd),
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
              child: Builder(
                builder: (context) {
                  final time = kSupportVisitTimeSlots[i];
                  final event = eventAt(ymd, time);
                  return _WeekSlotBar(
                    time: time,
                    event: event,
                    barColor: barColorOf(event),
                    siteOf: siteOf,
                    allowEmptyTap: true,
                    onTapEmpty: () => onEmptyTap(ymd, time),
                    onTapFilled: onFilledTap,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekSlotBar extends StatelessWidget {
  const _WeekSlotBar({
    required this.time,
    required this.event,
    required this.barColor,
    required this.siteOf,
    required this.allowEmptyTap,
    required this.onTapEmpty,
    required this.onTapFilled,
  });

  final String time;
  final SupportScheduleEvent? event;
  final Color barColor;
  final String Function(SupportCallLog) siteOf;
  final bool allowEmptyTap;
  final VoidCallback onTapEmpty;
  final ValueChanged<SupportScheduleEvent> onTapFilled;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final filled = e != null;
    final fill = filled ? barColor : const Color(0xFFFFFFFF);
    final site = filled ? siteOf(e.log) : '';
    final borderColor = filled
        ? Color.lerp(fill, const Color(0xFF111827), 0.38)!
        : allowEmptyTap
        ? const Color(0xFF6B7280)
        : const Color(0xFFD1D5DB);
    const radius = BorderRadius.all(Radius.circular(4));

    return Material(
      color: fill,
      elevation: filled ? 0.6 : 0,
      shadowColor: filled ? Colors.black26 : Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: filled
            ? () => onTapFilled(e)
            : allowEmptyTap
            ? onTapEmpty
            : null,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor, width: filled ? 1.3 : 1.1),
          ),
          child: filled
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Center(
                    child: Text(
                      site.isEmpty ? time : site,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
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
