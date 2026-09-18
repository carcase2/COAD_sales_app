import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_detail_sheet.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_provider.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class OverdueInstallListPage extends ConsumerStatefulWidget {
  const OverdueInstallListPage({
    super.key,
    this.initialAssignee,
    this.initialCalendarView = true,
    this.initialAllDates = false,
  });

  /// `null`이면 나, `전체`면 전원, 그 외는 해당 담당자.
  final String? initialAssignee;
  final bool initialCalendarView;

  /// true면 리스트에서 월/주 제한 없이 금일 이전 전체를 본다.
  final bool initialAllDates;

  @override
  ConsumerState<OverdueInstallListPage> createState() =>
      _OverdueInstallListPageState();
}

class _OverdueInstallListPageState
    extends ConsumerState<OverdueInstallListPage> {
  bool _mineOnly = true;
  String? _namedAssignee;
  bool _calendarView = true;
  bool _allDates = false;
  OverdueInstallRequestFilter _requestFilter = OverdueInstallRequestFilter.all;
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focused;
  late DateTime _selected;
  final Map<String, Color> _assigneeColors = {};

  @override
  void initState() {
    super.initState();
    final today = DateTime.parse(todayYmdSeoul());
    _focused = today;
    _selected = today.subtract(const Duration(days: 1));
    _calendarView = widget.initialCalendarView;
    _allDates = widget.initialAllDates;
    final initial = widget.initialAssignee?.trim();
    if (initial == null || initial.isEmpty) {
      _mineOnly = true;
      _namedAssignee = null;
    } else if (initial == '전체') {
      _mineOnly = false;
      _namedAssignee = null;
    } else {
      _mineOnly = false;
      _namedAssignee = initial;
    }
  }

  Future<void> _reload() async {
    ref.invalidate(overduePendingRowsProvider);
    await ref.read(overduePendingRowsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final async = ref.watch(overduePendingRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _namedAssignee == null
              ? '시공완료 안 된 건'
              : '시공완료 안 된 건 · $_namedAssignee',
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('미요청'),
                  selected:
                      _requestFilter ==
                      OverdueInstallRequestFilter.notRequested,
                  onSelected: (_) => setState(
                    () => _requestFilter =
                        OverdueInstallRequestFilter.notRequested,
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('요청함'),
                  selected:
                      _requestFilter == OverdueInstallRequestFilter.requested,
                  onSelected: (_) => setState(
                    () =>
                        _requestFilter = OverdueInstallRequestFilter.requested,
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('모두'),
                  selected: _requestFilter == OverdueInstallRequestFilter.all,
                  onSelected: (_) => setState(
                    () => _requestFilter = OverdueInstallRequestFilter.all,
                  ),
                ),
                const Spacer(),
                ChoiceChip(
                  label: const Text('달력'),
                  selected: _calendarView,
                  onSelected: (_) => setState(() => _calendarView = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('리스트'),
                  selected: !_calendarView,
                  onSelected: (_) => setState(() => _calendarView = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const AppLoading(message: '미시공 현장을 불러오는 중…'),
              error: (e, _) => AppErrorState(
                message: issuanceUserErrorMessage(e),
                onRetry: _reload,
              ),
              data: (rows) => _buildBody(rows, user?.name),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorOf(ColorScheme scheme, String name, List<String> ordered) {
    return hubAssigneeColor(
      scheme,
      name,
      cache: _assigneeColors,
      orderedAssignees: ordered,
    );
  }

  Widget _buildBody(List<OverdueInstallSite> rows, String? userName) {
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row.assigneeKey] = (counts[row.assigneeKey] ?? 0) + 1;
    }
    final assignees = overdueInstallAssigneeOrder(counts, userName);
    final scheme = Theme.of(context).colorScheme;

    final filtered = rows.where((row) {
      final named = _namedAssignee;
      final assigneeOk = named != null && named.isNotEmpty
          ? row.assigneeKey == named
          : !_mineOnly
          ? true
          : overdueInstallIsMine(row.assigneeKey, userName);
      if (!assigneeOk) return false;
      return overdueInstallMatchesRequestFilter(
        taxRequestCount: row.taxRequestCount,
        filter: _requestFilter,
      );
    }).toList();
    final byDay = <String, List<OverdueInstallSite>>{};
    for (final row in filtered) {
      (byDay[row.instalDt] ??= []).add(row);
    }

    final content = _calendarView
        ? Column(
            children: [
              _buildCalendar(byDay, assignees),
              const Divider(height: 1),
              Expanded(
                child: _buildSiteList(
                  _format == CalendarFormat.week
                      ? filtered
                            .where(
                              (row) =>
                                  overdueInstallInWeek(row.instalDt, _focused),
                            )
                            .toList()
                      : _sitesForSelectedDay(byDay),
                  userName,
                  assignees,
                ),
              ),
            ],
          )
        : Column(
            children: [
              if (!_allDates) _monthNav(),
              Expanded(
                child: _buildSiteList(
                  _allDates
                      ? filtered
                      : filtered.where((row) {
                          return _format == CalendarFormat.week
                              ? overdueInstallInWeek(row.instalDt, _focused)
                              : overdueInstallInMonth(row.instalDt, _focused);
                        }).toList(),
                  userName,
                  assignees,
                ),
              ),
            ],
          );

    return Column(
      children: [
        _assigneeFilterBar(scheme, assignees, counts, userName),
        Expanded(child: content),
      ],
    );
  }

  Future<void> _openDetail(OverdueInstallSite site) async {
    final created = await showOverdueInstallDetailSheet(
      context: context,
      site: site,
    );
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.displayName} 발급요청이 등록되었습니다.')),
    );
    await _reload();
  }

  Widget _assigneeFilterBar(
    ColorScheme scheme,
    List<String> assignees,
    Map<String, int> counts,
    String? userName,
  ) {
    final mineSelected =
        (_mineOnly && _namedAssignee == null) ||
        (_namedAssignee != null &&
            overdueInstallIsMine(_namedAssignee!, userName));
    final allSelected = !_mineOnly && _namedAssignee == null;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        children: [
          _filterChip(
            label: '나',
            count: userName == null ? 0 : (counts[userName.trim()] ?? 0),
            color: userName == null
                ? scheme.primary
                : _colorOf(scheme, userName.trim(), assignees),
            selected: mineSelected,
            onTap: () => setState(() {
              _mineOnly = true;
              _namedAssignee = null;
            }),
          ),
          const SizedBox(width: 6),
          _filterChip(
            label: '전체',
            count: counts.values.fold<int>(0, (s, n) => s + n),
            color: scheme.onSurfaceVariant,
            selected: allSelected,
            onTap: () => setState(() {
              _mineOnly = false;
              _namedAssignee = null;
            }),
          ),
          for (final name in assignees)
            if (!overdueInstallIsMine(name, userName)) ...[
              const SizedBox(width: 6),
              _filterChip(
                label: name,
                count: counts[name] ?? 0,
                color: _colorOf(scheme, name, assignees),
                selected: _namedAssignee == name,
                onTap: () => setState(() {
                  _mineOnly = false;
                  _namedAssignee = name;
                }),
              ),
            ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected ? color : color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OverdueInstallSite> _sitesForSelectedDay(
    Map<String, List<OverdueInstallSite>> byDay,
  ) {
    return byDay[overdueInstallYmd(_selected)] ?? const [];
  }

  Widget _monthNav() {
    final label = _format == CalendarFormat.week
        ? '${overdueInstallYmd(overdueInstallMondayOf(_focused))} 주'
        : '${_focused.year}년 ${_focused.month}월';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('월간'),
                selected: _format == CalendarFormat.month,
                onSelected: (_) =>
                    setState(() => _format = CalendarFormat.month),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('주간'),
                selected: _format == CalendarFormat.week,
                onSelected: (_) =>
                    setState(() => _format = CalendarFormat.week),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: '이전',
                onPressed: () => setState(() {
                  _focused = _format == CalendarFormat.week
                      ? _focused.subtract(const Duration(days: 7))
                      : DateTime(_focused.year, _focused.month - 1, 1);
                }),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '다음',
                onPressed: () => setState(() {
                  _focused = _format == CalendarFormat.week
                      ? _focused.add(const Duration(days: 7))
                      : DateTime(_focused.year, _focused.month + 1, 1);
                }),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(
    Map<String, List<OverdueInstallSite>> byDay,
    List<String> assignees,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.parse(todayYmdSeoul());
    final firstDay = DateTime(today.year - 2, today.month, today.day);
    var focused = _focused;
    if (focused.isAfter(today)) focused = today;
    if (focused.isBefore(firstDay)) focused = firstDay;
    final isWeek = _format == CalendarFormat.week;
    return TableCalendar<OverdueInstallSite>(
      locale: 'ko_KR',
      firstDay: firstDay,
      lastDay: today,
      focusedDay: focused,
      selectedDayPredicate: (day) => isSameDay(day, _selected),
      calendarFormat: _format,
      availableCalendarFormats: const {
        CalendarFormat.month: '월간',
        CalendarFormat.week: '주간',
      },
      startingDayOfWeek: StartingDayOfWeek.monday,
      rowHeight: isWeek ? 96 : 68,
      daysOfWeekHeight: 22,
      eventLoader: (day) => byDay[overdueInstallYmd(day)] ?? const [],
      onDaySelected: (selected, focusedDay) {
        setState(() {
          _selected = selected;
          _focused = focusedDay;
        });
        final events = byDay[overdueInstallYmd(selected)] ?? const [];
        if (events.length == 1) {
          unawaited(_openDetail(events.first));
        }
      },
      onPageChanged: (focusedDay) => setState(() => _focused = focusedDay),
      onFormatChanged: (format) {
        if (_format == format) return;
        setState(() => _format = format);
      },
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: true,
        formatButtonShowsNext: false,
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        markersMaxCount: 0,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _dayCell(
          scheme,
          day,
          byDay,
          assignees,
          selected: false,
          today: false,
        ),
        todayBuilder: (context, day, focusedDay) => _dayCell(
          scheme,
          day,
          byDay,
          assignees,
          selected: false,
          today: true,
        ),
        selectedBuilder: (context, day, focusedDay) => _dayCell(
          scheme,
          day,
          byDay,
          assignees,
          selected: true,
          today: false,
        ),
        outsideBuilder: (context, day, focusedDay) => _dayCell(
          scheme,
          day,
          byDay,
          assignees,
          selected: false,
          today: false,
          outside: true,
        ),
      ),
    );
  }

  Widget _dayCell(
    ColorScheme scheme,
    DateTime day,
    Map<String, List<OverdueInstallSite>> byDay,
    List<String> assignees, {
    required bool selected,
    required bool today,
    bool outside = false,
  }) {
    final events = byDay[overdueInstallYmd(day)] ?? const [];
    final names = overdueInstallUniqueNames(events.map((e) => e.assigneeKey));
    final isWeek = _format == CalendarFormat.week;
    final maxNames = isWeek ? 2 : 1;
    final shown = names.take(maxNames).toList();
    final extra = names.length - shown.length;
    final tint = names.isEmpty
        ? scheme.primary
        : _colorOf(scheme, names.first, assignees);
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 1),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: selected
            ? tint.withValues(alpha: 0.16)
            : today
            ? scheme.primary.withValues(alpha: 0.08)
            : events.isNotEmpty
            ? tint.withValues(alpha: 0.08)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: tint, width: 1.4)
            : events.isNotEmpty
            ? Border.all(color: tint.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 11,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: outside
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : selected
                  ? scheme.primary
                  : scheme.onSurface,
            ),
          ),
          if (shown.isNotEmpty) const SizedBox(height: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in shown)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isWeek ? 10 : 9,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: _colorOf(
                        scheme,
                        name,
                        assignees,
                      ).withValues(alpha: outside ? 0.5 : 1),
                    ),
                  ),
                if (extra > 0)
                  Text(
                    '외 $extra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isWeek ? 10 : 9,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: outside ? 0.5 : 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteList(
    List<OverdueInstallSite> sites,
    String? userName,
    List<String> assignees,
  ) {
    final groups = overdueInstallGroupByAssignee(
      sites,
      assigneeOf: (row) => row.assigneeKey,
      dateOf: (row) => row.instalDt,
      userName: userName,
    );
    return RefreshIndicator(
      onRefresh: _reload,
      child: sites.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                AppEmpty(
                  message: '오늘이 지났고 시공완료가 안 된 현장이 없습니다.',
                  icon: Icons.event_busy_outlined,
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final (name, rows) = groups[i];
                final mine = overdueInstallIsMine(name, userName);
                final color = _colorOf(
                  Theme.of(context).colorScheme,
                  name,
                  assignees,
                );
                return Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mine ? '나 · $name' : name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${rows.length}건',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var j = 0; j < rows.length; j++) ...[
                        if (j > 0) const SizedBox(height: 8),
                        _PendingCard(
                          site: rows[j],
                          showAssignee: false,
                          accent: color,
                          onTap: () => unawaited(_openDetail(rows[j])),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RequestBadge extends StatelessWidget {
  const _RequestBadge({required this.site});

  final OverdueInstallSite site;

  @override
  Widget build(BuildContext context) {
    final requested = site.hasTaxRequest;
    final color = requested ? Colors.teal : Colors.deepOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        overdueInstallRequestBadge(taxRequestCount: site.taxRequestCount),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color.shade800,
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.site,
    required this.onTap,
    this.showAssignee = true,
    this.accent,
  });

  final OverdueInstallSite site;
  final VoidCallback onTap;
  final bool showAssignee;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vat = site.vatSplit;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (accent ?? Colors.deepOrange).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      site.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (showAssignee) ...[
                    const SizedBox(width: 8),
                    Text(
                      site.assigneeKey,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.deepOrange.shade800,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _RequestBadge(site: site),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  site.instalDt,
                  if (site.plantNm.isNotEmpty) site.plantNm,
                  if (site.itemCd.isNotEmpty) site.itemCd,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
              if (vat != null || site.remainPay != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (vat != null) '공급가액 ${_won(vat.supply)}',
                    if (site.remainPay != null) '잔금 ${_won(site.remainPay!)}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _won(int n) {
    final s = n.toString();
    final chars = <String>[];
    for (var i = 0; i < s.length; i++) {
      final idx = s.length - i;
      chars.add(s[i]);
      if (idx > 1 && idx % 3 == 1) chars.add(',');
    }
    return '${chars.join()}원';
  }
}
