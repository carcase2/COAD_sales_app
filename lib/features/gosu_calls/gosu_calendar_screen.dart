import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_detail_screen.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class GosuCalendarScreen extends ConsumerStatefulWidget {
  const GosuCalendarScreen({super.key});

  @override
  ConsumerState<GosuCalendarScreen> createState() => _GosuCalendarScreenState();
}

class _GosuCalendarScreenState extends ConsumerState<GosuCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  List<GosuSalesCall> _rows = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final today = todayYmdSeoul();
    _focused = DateTime.tryParse(today) ?? DateTime.now();
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
      final monthStart = DateTime(_focused.year, _focused.month, 1);
      final monthEnd = DateTime(_focused.year, _focused.month + 1, 0);
      final rows = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchScheduledForCalendar(
            fromYmd: _ymd(monthStart),
            toYmdInclusive: _ymd(monthEnd),
          );
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

  List<GosuSalesCall> _forDay(DateTime day) {
    final ymd = _ymd(day);
    return _rows
        .where((r) => r.followCalendarDateKey == ymd && isGosuCalendarScheduled(r))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final selectedRows = _forDay(_selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('자동문의고수 달력'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const AppLoading(message: '예정 일정을 불러오는 중…')
          : _error != null
          ? AppErrorState(
              message: koreanErrorMessage(_error!),
              onRetry: _load,
            )
          : Column(
              children: [
                TableCalendar<GosuSalesCall>(
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
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selected = selected;
                      _focused = focused;
                    });
                  },
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
                      '${_ymd(_selected)} 예정 · ${selectedRows.length}건',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                Expanded(
                  child: selectedRows.isEmpty
                      ? const AppEmpty(message: '이 날짜에 예정된 팔로업이 없습니다.')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: selectedRows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final row = selectedRows[i];
                            return ListTile(
                              tileColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                row.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${row.displayPhone}\n${gosuStageLabel(row.callStage)}',
                              ),
                              isThreeLine: true,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GosuCallDetailScreen(
                                      id: row.id,
                                      initial: row,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
