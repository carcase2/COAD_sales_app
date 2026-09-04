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
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportVisitWeekBoard extends ConsumerStatefulWidget {
  const SupportVisitWeekBoard({
    super.key,
    required this.anchorYmd,
    required this.events,
    required this.teams,
    required this.onReload,
    this.branch = '전체',
  });

  final String anchorYmd;
  final List<SupportScheduleEvent> events;
  final List<SupportAsVisitTeam> teams;
  final Future<void> Function() onReload;
  final String branch;

  @override
  ConsumerState<SupportVisitWeekBoard> createState() =>
      _SupportVisitWeekBoardState();
}

class _SupportVisitWeekBoardState extends ConsumerState<SupportVisitWeekBoard> {
  String? _teamId;

  List<String> get _days => seoulSundayWeekDays(widget.anchorYmd);

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
    if (_teamId != null) {
      rows = rows.where((e) => (e.log.visitTeamId ?? '') == _teamId).toList();
    }
    return rows;
  }

  SupportScheduleEvent? _at(String ymd, String time, String teamId) {
    for (final e in _visits) {
      if (e.ymd != ymd) continue;
      if ((e.log.visitTeamId ?? '') != teamId) continue;
      final t = normalizeSupportVisitTime(e.scheduledTime ?? e.log.visitTime);
      if (t == time) return e;
    }
    return null;
  }

  String _site(SupportCallLog log) {
    final site = parseSupportIssueBody(log.issue).siteName.trim();
    if (site.isNotEmpty) return site;
    final name = log.customerName.trim();
    return name.isEmpty ? '(현장 없음)' : name;
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
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final teams = _teams;
    final days = _days;
    if (teams.isEmpty) {
      return const Center(child: Text('이 지사에 방문 팀이 없습니다.'));
    }
    final team = teams.firstWhere(
      (t) => t.id == _teamId,
      orElse: () => teams.first,
    );

    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final t in teams)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: _teamId == t.id,
                    onSelected: (_) => setState(() => _teamId = t.id),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Text(
            '빈 칸을 누르면 현장을 넣고, 채워진 칸은 변경할 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: (days.length * 92.0) + 56,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 56),
                      for (final ymd in days)
                        SizedBox(
                          width: 92,
                          child: Text(
                            _dayHead(ymd),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: ymd == todayYmdSeoul()
                                  ? accent
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: kSupportVisitTimeSlots.length,
                      itemBuilder: (_, i) {
                        final time = kSupportVisitTimeSlots[i];
                        return SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  time,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              for (final ymd in days)
                                SizedBox(
                                  width: 92,
                                  child: _Cell(
                                    event: _at(ymd, time, team.id),
                                    accent: accent,
                                    siteOf: _site,
                                    onTapEmpty: () {
                                      HapticFeedback.selectionClick();
                                      unawaited(
                                        _onEmpty(
                                          ymd: ymd,
                                          time: time,
                                          team: team,
                                        ),
                                      );
                                    },
                                    onTapFilled: (e) {
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
            ),
          ),
        ),
      ],
    );
  }

  String _dayHead(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return ymd;
    final dt = DateTime(
      int.tryParse(p[0]) ?? 0,
      int.tryParse(p[1]) ?? 1,
      int.tryParse(p[2]) ?? 1,
    );
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return '${int.parse(p[1])}/${int.parse(p[2])}\n${labels[dt.weekday % 7]}';
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.event,
    required this.accent,
    required this.siteOf,
    required this.onTapEmpty,
    required this.onTapFilled,
  });

  final SupportScheduleEvent? event;
  final Color accent;
  final String Function(SupportCallLog) siteOf;
  final VoidCallback onTapEmpty;
  final ValueChanged<SupportScheduleEvent> onTapFilled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: e == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: e == null ? onTapEmpty : () => onTapFilled(e),
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                e == null ? '+' : siteOf(e.log),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: e == null ? scheme.onSurfaceVariant : accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
