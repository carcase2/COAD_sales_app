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
  return repo.fetchCalls(incompleteOnly: true, limit: 500, includeCallHistory: false);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(todayStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('고객전화'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayStatsProvider);
          ref.invalidate(incompleteCallsProvider);
          await ref.read(todayStatsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              user?.name != null ? '${user!.name} 님' : '환영합니다',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '기준: Asia/Seoul · ${todayYmdSeoul()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            statsAsync.when(
              data: (s) => _StatsCard(stats: s),
              loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )),
              error: (e, _) => _ErrorCard(
                message: koreanErrorMessage(e),
                onRetry: () => ref.invalidate(todayStatsProvider),
              ),
            ),
            const SizedBox(height: 16),
            const _IncompleteCalendar(),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SalesCallListScreen(mode: ListQueryMode.today),
                  ),
                );
              },
              icon: const Icon(Icons.today_outlined),
              label: const Text('오늘 통화 목록'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SalesCallListScreen(mode: ListQueryMode.incomplete),
                  ),
                );
              },
              icon: const Icon(Icons.phone_missed_outlined),
              label: const Text('미통화·미완료 위주'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const SalesCallListScreen(mode: ListQueryMode.recent),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('최근 전체(50건)'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SalesCallCreateScreen()),
          );
        },
        icon: const Icon(Icons.add_call),
        label: const Text('새 통화'),
      ),
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
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
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

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(incompleteCallsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Text(
                '미종료 캘린더',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            asyncCalls.when(
              data: (calls) {
                // Group by date (yyyy-mm-dd)
                final Map<String, int> incompleteCountByDate = {};
                for (final c in calls) {
                  if (c.callDate != null && c.callDate!.length >= 10) {
                    final dateKey = c.callDate!.substring(0, 10);
                    incompleteCountByDate[dateKey] = (incompleteCountByDate[dateKey] ?? 0) + 1;
                  }
                }

                return TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  locale: 'ko_KR',
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      final dateKey = date.toIso8601String().substring(0, 10);
                      final count = incompleteCountByDate[dateKey] ?? 0;
                      if (count > 0) {
                        return Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
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
                );
              },
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 300,
                child: Center(child: Text(koreanErrorMessage(e))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

