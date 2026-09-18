import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_detail_sheet.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_provider.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class OverdueInstallListPage extends ConsumerStatefulWidget {
  const OverdueInstallListPage({super.key});

  @override
  ConsumerState<OverdueInstallListPage> createState() =>
      _OverdueInstallListPageState();
}

class _OverdueInstallListPageState
    extends ConsumerState<OverdueInstallListPage> {
  bool _mineOnly = true;
  bool _calendarView = true;
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focused;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = DateTime.parse(todayYmdSeoul());
    _focused = today;
    _selected = today.subtract(const Duration(days: 1));
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
        title: const Text('시공완료 안 된 건'),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('나'),
                  selected: _mineOnly,
                  onSelected: (_) => setState(() => _mineOnly = true),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('전체'),
                  selected: !_mineOnly,
                  onSelected: (_) => setState(() => _mineOnly = false),
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

  Widget _buildBody(List<OverdueInstallSite> rows, String? userName) {
    final filtered = rows.where((row) {
      if (!_mineOnly) return true;
      return overdueInstallIsMine(row.assigneeKey, userName);
    }).toList();
    final byDay = <String, List<OverdueInstallSite>>{};
    for (final row in filtered) {
      (byDay[row.instalDt] ??= []).add(row);
    }

    if (_calendarView) {
      return Column(
        children: [
          _buildCalendar(byDay),
          const Divider(height: 1),
          Expanded(child: _buildSiteList(_sitesForSelectedDay(byDay))),
        ],
      );
    }

    final visible = filtered.where((row) {
      return _format == CalendarFormat.week
          ? overdueInstallInWeek(row.instalDt, _focused)
          : overdueInstallInMonth(row.instalDt, _focused);
    }).toList();
    return Column(
      children: [
        _monthNav(),
        Expanded(child: _buildSiteList(visible)),
      ],
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

  Widget _buildCalendar(Map<String, List<OverdueInstallSite>> byDay) {
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
      rowHeight: isWeek ? 92 : 62,
      daysOfWeekHeight: 22,
      eventLoader: (day) => byDay[overdueInstallYmd(day)] ?? const [],
      onDaySelected: (selected, focusedDay) {
        setState(() {
          _selected = selected;
          _focused = focusedDay;
        });
        final events = byDay[overdueInstallYmd(selected)] ?? const [];
        if (events.length == 1) {
          showOverdueInstallDetailSheet(context: context, site: events.first);
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
        defaultBuilder: (context, day, focusedDay) =>
            _dayCell(scheme, day, byDay, selected: false, today: false),
        todayBuilder: (context, day, focusedDay) =>
            _dayCell(scheme, day, byDay, selected: false, today: true),
        selectedBuilder: (context, day, focusedDay) =>
            _dayCell(scheme, day, byDay, selected: true, today: false),
        outsideBuilder: (context, day, focusedDay) => _dayCell(
          scheme,
          day,
          byDay,
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
    Map<String, List<OverdueInstallSite>> byDay, {
    required bool selected,
    required bool today,
    bool outside = false,
  }) {
    final events = byDay[overdueInstallYmd(day)] ?? const [];
    final names = overdueInstallUniqueNames(events.map((e) => e.assigneeKey));
    final isWeek = _format == CalendarFormat.week;
    final maxNames = isWeek ? 3 : 2;
    final shown = names.take(maxNames).toList();
    final extra = names.length - shown.length;
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : today
            ? scheme.primary.withValues(alpha: 0.08)
            : events.isNotEmpty
            ? Colors.deepOrange.withValues(alpha: 0.08)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: scheme.primary, width: 1.4)
            : events.isNotEmpty
            ? Border.all(color: Colors.deepOrange.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: outside
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : selected
                  ? scheme.primary
                  : scheme.onSurface,
            ),
          ),
          for (final name in shown)
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isWeek ? 10 : 9,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Colors.deepOrange.shade800.withValues(
                  alpha: outside ? 0.5 : 1,
                ),
              ),
            ),
          if (extra > 0)
            Text(
              '외 $extra',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.deepOrange.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSiteList(List<OverdueInstallSite> sites) {
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
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: sites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _PendingCard(
                site: sites[i],
                onTap: () => showOverdueInstallDetailSheet(
                  context: context,
                  site: sites[i],
                ),
              ),
            ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.site, required this.onTap});

  final OverdueInstallSite site;
  final VoidCallback onTap;

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
              color: Colors.deepOrange.withValues(alpha: 0.28),
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
              if (vat != null) ...[
                const SizedBox(height: 6),
                Text(
                  '공급가액 ${_won(vat.supply)}',
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
