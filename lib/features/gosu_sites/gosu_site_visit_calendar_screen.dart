import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_detail_screen.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 홈페이지 문의(고수) 방문 달력 — 고수에 입력된 방문예정일(onsite_at) 기준.
class GosuSiteVisitCalendarScreen extends ConsumerStatefulWidget {
  const GosuSiteVisitCalendarScreen({super.key});

  @override
  ConsumerState<GosuSiteVisitCalendarScreen> createState() =>
      _GosuSiteVisitCalendarScreenState();
}

class _GosuSiteVisitCalendarScreenState
    extends ConsumerState<GosuSiteVisitCalendarScreen> {
  late DateTime _focused;
  late DateTime _selected;
  List<GosuSite> _rows = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _focused = DateTime.parse(todayYmdSeoul());
    _selected = _focused;
    _load();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final first = DateTime(_focused.year, _focused.month, 1);
      final last = DateTime(_focused.year, _focused.month + 1, 0);
      final rows = await ref
          .read(gosuSitesRepositoryProvider)
          .fetchVisitsBetween(_ymd(first), _ymd(last));
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  List<GosuSite> _forDay(DateTime day) {
    final ymd = _ymd(day);
    return _rows
        .where(
          (r) => r.onsiteAt != null && ymdSeoulFromDateTime(r.onsiteAt!) == ymd,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final dayRows = _forDay(_selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈페이지 문의 방문 달력'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar<GosuSite>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: _forDay,
            locale: 'ko_KR',
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: accent,
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
            onDaySelected: (selected, focused) => setState(() {
              _selected = selected;
              _focused = focused;
            }),
            onPageChanged: (focused) {
              _focused = focused;
              _load();
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_ymd(_selected)} 방문 · ${dayRows.length}건',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoading(message: '방문 일정을 불러오는 중…')
                : _error != null
                ? AppErrorState(
                    message: koreanErrorMessage(_error!),
                    onRetry: _load,
                  )
                : dayRows.isEmpty
                ? const AppEmpty(message: '이 날짜에 방문 예정이 없습니다.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: dayRows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = dayRows[i];
                      return ListTile(
                        tileColor: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          '${formatSeoulMonthDayTime(s.onsiteAt).split(' ').last} · ${s.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${gosuSiteRegion(s)} · ${s.productLabel}\n담당 ${s.workerName ?? '미배정'} · ${gosuSiteStatusLabel(s.workerStatus)}',
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GosuSiteDetailScreen(initial: s),
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
