import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchTodayStats();
});

final incompleteCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(incompleteOnly: true, excludeSimpleInquiries: true, limit: 500, includeCallHistory: false);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(todayStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('고객전화'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '오늘 요약', icon: Icon(Icons.dashboard_outlined, size: 20)),
              Tab(text: '미종료 달력', icon: Icon(Icons.calendar_month_outlined, size: 20)),
            ],
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        drawer: Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person, size: 40, color: scheme.onPrimaryContainer),
                ),
                accountName: Text(user?.name ?? '사용자', style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(user?.id ?? ''),
                decoration: BoxDecoration(color: scheme.primary),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('설정'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const Divider(),
              const Spacer(),
              ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('로그아웃', style: TextStyle(color: scheme.error)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('로그아웃'),
                      content: const Text('정말 로그아웃 하시겠습니까?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('로그아웃')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(authControllerProvider.notifier).logout();
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 탭 1: 오늘 요약 뷰
            RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(todayStatsProvider);
                await ref.read(todayStatsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  statsAsync.when(
                    data: (s) => _StatsCard(stats: s),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => _ErrorCard(
                      message: koreanErrorMessage(e),
                      onRetry: () => ref.invalidate(todayStatsProvider),
                    ),
                  ),
                ],
              ),
            ),
            // 탭 2: 미종료 캘린더 뷰
            const _IncompleteCalendar(),
          ],
        ),
        floatingActionButton: Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SalesCallCreateScreen()),
              );
            },
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.tertiary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SalesCallCreateScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_call, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Text(
                  '새 통화 등록',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final TodayStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('오늘 요약', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatVertical(
                    label: '금일 접수',
                    value: stats.todayCount?.toString() ?? '0',
                    color: scheme.primary,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesCallListScreen(mode: ListQueryMode.today))),
                  ),
                ),
                Expanded(
                  child: _StatVertical(
                    label: '미통화',
                    value: stats.incompleteCount?.toString() ?? '0',
                    color: scheme.error,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesCallListScreen(mode: ListQueryMode.incomplete))),
                  ),
                ),
                Expanded(
                  child: _StatVertical(
                    label: '완료',
                    value: stats.completedToday?.toString() ?? '0',
                    color: Colors.green.shade600,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesCallListScreen(mode: ListQueryMode.completedToday))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if ((stats.incompleteCount ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: scheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '오늘 접수된 미통화 건이 ${stats.incompleteCount ?? 0}건 있습니다.\n(단순/설계문의 제외됨)',
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatVertical extends StatelessWidget {
  const _StatVertical({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

class _IncompleteCalendar extends ConsumerStatefulWidget {
  const _IncompleteCalendar();

  @override
  ConsumerState<_IncompleteCalendar> createState() => _IncompleteCalendarState();
}

class _IncompleteCalendarState extends ConsumerState<_IncompleteCalendar> {
  DateTime _focusedDay = DateTime.now();
  String _selectedAssignee = '전체';

  Color _colorForAssignee(String assignee, ColorScheme scheme) {
    if (assignee == '미지정') return scheme.surfaceContainerHighest;
    final colors = [
      Colors.blue.shade100,
      Colors.red.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
    ];
    return colors[assignee.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(incompleteCallsProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) {
        // 1. Calculate counts for filter bar
        final Map<String, int> counts = {'전체': calls.length};
        for (var c in calls) {
          final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
          counts[a] = (counts[a] ?? 0) + 1;
        }

        final sortedAssignees = counts.keys.toList()
          ..sort((a, b) {
            if (a == '전체') return -1;
            if (b == '전체') return 1;
            final countA = counts[a] ?? 0;
            final countB = counts[b] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            return a.compareTo(b);
          });

        // 2. Prepare calendar markers (group by date) filtered by selected assignee
        final Map<String, int> dateMarkers = {};
        for (final c in calls) {
          final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
          if (_selectedAssignee != '전체' && a != _selectedAssignee) continue;

          if (c.callDate != null && c.callDate!.length >= 10) {
            final dateKey = c.callDate!.substring(0, 10);
            dateMarkers[dateKey] = (dateMarkers[dateKey] ?? 0) + 1;
          }
        }

        return Column(
          children: [
            // ─── 상단 담당자 필터 바 (캘린더용) ───
            Container(
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.3))),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: sortedAssignees.length,
                itemBuilder: (context, idx) {
                  final assignee = sortedAssignees[idx];
                  final count = counts[assignee] ?? 0;
                  final isSelected = _selectedAssignee == assignee;
                  final color = _colorForAssignee(assignee, scheme);

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedAssignee = assignee),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : color.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              assignee,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.black87 : Colors.black54,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($count)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.black87 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // ─── 캘린더 영역 ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      locale: 'ko_KR',
                      daysOfWeekHeight: 40,
                      rowHeight: 52,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final dateKey = date.toIso8601String().substring(0, 10);
                          final count = dateMarkers[dateKey] ?? 0;
                          if (count > 0) {
                            return Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: scheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: scheme.onError,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                        final dateStr = selectedDay.toIso8601String().substring(0, 10);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SalesCallListScreen(
                              mode: ListQueryMode.incompleteByDate,
                              date: dateStr,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
    );
  }
}

