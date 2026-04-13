import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

final todayCallsContentProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(date: todayYmdSeoul(), limit: 100, includeCallHistory: false);
});

final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchTodayStats();
});

final incompleteCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(incompleteOnly: true, limit: 1000);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _pendingCount = 0;
  late ScrollController _scrollController;
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndSync());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isFabVisible) setState(() => _isFabVisible = false);
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isFabVisible) setState(() => _isFabVisible = true);
    }
  }

  Future<void> _checkAndSync() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    final count = await repo.getPendingCount();
    if (mounted) setState(() => _pendingCount = count);

    if (count > 0) {
      final success = await repo.syncPendingCalls();
      final newCount = await repo.getPendingCount();
      if (mounted) {
        setState(() => _pendingCount = newCount);
        if (success > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('미전송 상담 $success건이 동기화되었습니다.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(todayStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          final barBg = scheme.primary;
          final onBar = scheme.onPrimary;

          return Scaffold(
            backgroundColor: scheme.surface,
            appBar: AppBar(
              title: const Text('고객전화'),
              backgroundColor: barBg,
              foregroundColor: onBar,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      'v$kAppVersion',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onBar.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                controller: tabController,
                tabs: const [
                  Tab(text: '오늘 요약', icon: Icon(Icons.dashboard_rounded, size: 18)),
                  Tab(text: '미종료 달력', icon: Icon(Icons.calendar_month_rounded, size: 18)),
                ],
                indicatorColor: onBar,
                indicatorWeight: 3,
                labelColor: onBar,
                unselectedLabelColor: onBar.withValues(alpha: 0.65),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
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
                  controller: tabController, // 명시적 연결
                  children: [
                    // 탭 1: 오늘 요약 뷰
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(todayStatsProvider);
                        ref.invalidate(todayCallsContentProvider);
                        await Future.wait([
                          ref.read(todayStatsProvider.future),
                          ref.read(todayCallsContentProvider.future),
                          _checkAndSync(),
                        ]);
                      },
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        children: [
                          if (_pendingCount > 0) _buildPendingSyncBanner(scheme),
                          if (_pendingCount > 0) const SizedBox(height: 12),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 20),
                          const _IncompleteBreakdown(),
                        ],
                      ),
                    ),
                    // 탭 2: 미종료 캘린더 뷰
                    const _IncompleteCalendar(),
                  ],
                ),
                floatingActionButton: AnimatedScale(
                  scale: _isFabVisible ? 1.0 : 0.0,
                  alignment: Alignment.bottomRight,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
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
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
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
                floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              );
        },
      ),
    );
  }


  Widget _buildPendingSyncBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_sync_outlined, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '동기화를 기다리는 상담이 $_pendingCount건 있습니다.',
              style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _checkAndSync,
            child: const Text('지금 전송'),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 22, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  '오늘 요약',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
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
          ],
        ),
      ),
    );
  }
}

enum _SummaryFilter { today, week, month, total }

class _IncompleteBreakdown extends ConsumerStatefulWidget {
  const _IncompleteBreakdown();

  @override
  ConsumerState<_IncompleteBreakdown> createState() => _IncompleteBreakdownState();
}

class _IncompleteBreakdownState extends ConsumerState<_IncompleteBreakdown> {
  _SummaryFilter _currentFilter = _SummaryFilter.today; // 금일이 기본값

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(incompleteCallsProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) {
        if (calls.isEmpty) return const SizedBox.shrink();

        // 1. Get filtered list based on date
        final now = DateTime.now(); // Current time (local)
        final todayStr = todayYmdSeoul();
        
        // Mondary start for the week
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final startOfMonth = DateTime(now.year, now.month, 1);

        final filteredCalls = calls.where((c) {
          if (c.callDate == null || c.callDate!.length < 10) return _currentFilter == _SummaryFilter.total;
          final callDt = DateTime.tryParse(c.callDate!.substring(0, 10));
          if (callDt == null) return _currentFilter == _SummaryFilter.total;

          switch (_currentFilter) {
            case _SummaryFilter.today:
              return c.callDate!.startsWith(todayStr);
            case _SummaryFilter.week:
              return callDt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
                     callDt.isBefore(now.add(const Duration(days: 1)));
            case _SummaryFilter.month:
              return callDt.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
            case _SummaryFilter.total:
              return true;
          }
        }).toList();

        if (filteredCalls.isEmpty && _currentFilter != _SummaryFilter.total) {
          return _buildEmptyContent(scheme);
        }

        // 2. Count per assignee
        final Map<String, int> counts = {};
        for (var c in filteredCalls) {
          final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
          counts[a] = (counts[a] ?? 0) + 1;
        }

        final sorted = counts.keys.toList()
          ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

        final total = filteredCalls.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '담당자별 미통화 현황',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ─── 필터 버튼 (개별 컬러 커스텀 필터) ───
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    children: _SummaryFilter.values.map((filter) {
                      final isSelected = _currentFilter == filter;
                      Color filterColor;
                      String label;
                      
                      switch (filter) {
                        case _SummaryFilter.today:
                          filterColor = scheme.primary;
                          label = '금일';
                          break;
                        case _SummaryFilter.week:
                          filterColor = scheme.tertiary;
                          label = '금주';
                          break;
                        case _SummaryFilter.month:
                          filterColor = scheme.secondary;
                          label = '금월';
                          break;
                        case _SummaryFilter.total:
                          filterColor = scheme.onSurfaceVariant;
                          label = '전체';
                          break;
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentFilter = filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? filterColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              final count = counts[name] ?? 0;
              final percent = total > 0 ? count / total : 0.0;
              
              final rank = idx + 1;
              Color rankAccent = scheme.primary;
              Color? rankBg;
              if (rank == 1) {
                rankAccent = const Color(0xFFB8860B);
                rankBg = const Color(0xFFFFF8E7);
              } else if (rank == 2) {
                rankAccent = const Color(0xFF6B7280);
                rankBg = const Color(0xFFF3F4F6);
              } else if (rank == 3) {
                rankAccent = const Color(0xFFA16207);
                rankBg = const Color(0xFFFFFBEB);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: rankBg,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SalesCallListScreen(
                          mode: ListQueryMode.incomplete,
                          initialAssignee: name,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: rank <= 3
                                      ? rankAccent.withValues(alpha: 0.15)
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: rank <= 3 ? rankAccent : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: rank <= 3 ? FontWeight.w700 : FontWeight.w500,
                                    ),
                              ),
                            ),
                            Text(
                              '$count',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: rank <= 3 ? rankAccent : scheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              ' / $total',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: rank <= 3 ? rankAccent : scheme.primary.withValues(alpha: 0.55),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyContent(ColorScheme scheme) {
    return Column(
      children: [
        // ─── 필터 버튼 (데이터 없을 때도 동일하게 유지) ───
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: _SummaryFilter.values.map((filter) {
                final isSelected = _currentFilter == filter;
                Color filterColor;
                String label;

                switch (filter) {
                  case _SummaryFilter.today:
                    filterColor = scheme.primary;
                    label = '금일';
                    break;
                  case _SummaryFilter.week:
                    filterColor = scheme.tertiary;
                    label = '금주';
                    break;
                  case _SummaryFilter.month:
                    filterColor = scheme.secondary;
                    label = '금월';
                    break;
                  case _SummaryFilter.total:
                    filterColor = scheme.onSurfaceVariant;
                    label = '전체';
                    break;
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? filterColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 52, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  '선택한 기간에 미통화 건이 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.05,
                  letterSpacing: -0.5,
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, color: scheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onErrorContainer, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ),
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
        // 1. Filter calls by the currently focused month
        final focusedYear = _focusedDay.year;
        final focusedMonth = _focusedDay.month;
        final focusedMonthStr = "$focusedYear-${focusedMonth.toString().padLeft(2, '0')}";

        final visibleCallsInMonth = calls.where((c) {
          if (c.callDate == null || c.callDate!.length < 7) return false;
          return c.callDate!.startsWith(focusedMonthStr);
        }).toList();

        // 2. Calculate counts for filter bar (Only for the visible month)
        final Map<String, int> counts = {'전체': visibleCallsInMonth.length};
        for (var c in visibleCallsInMonth) {
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

        // 2-1. Smart default: filter by logged-in user if not already filtered
        final user = ref.watch(authControllerProvider);
        final userName = user?.name;
        if (_selectedAssignee == '전체' && userName != null && counts.containsKey(userName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedAssignee == '전체') {
              setState(() => _selectedAssignee = userName);
            }
          });
        }

        // 3. Prepare calendar markers (group by date) filtered by selected assignee
        final Map<String, int> dateMarkers = {};
        for (final c in calls) { // Markers should still be pre-calculated for all calls to show them as user swipes? 
          // Usually markers are calculated for all, but user asked "그달 숫자만 카운트 되게".
          // This refers to the top "Filter Chips".
          final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
          if (_selectedAssignee != '전체' && a != _selectedAssignee) continue;

          if (c.callDate != null && c.callDate!.length >= 10) {
            final dateKey = c.callDate!.substring(0, 10);
            dateMarkers[dateKey] = (dateMarkers[dateKey] ?? 0) + 1;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 200), // 압도적인 하단 여백 추가
          children: [
            // ─── 상단 담당자 필터 바 (캘린더용) ───
            Container(
              height: 70,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.3)),
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
                                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($count)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
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
            Card(
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
                  availableGestures: AvailableGestures.none, // ListView 스크롤에 맡김
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
                          initialAssignee: _selectedAssignee,
                        ),
                      ),
                    );
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
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

