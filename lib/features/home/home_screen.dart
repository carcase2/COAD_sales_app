import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class ConsultationStatusScreen extends ConsumerStatefulWidget {
  const ConsultationStatusScreen({super.key});

  @override
  ConsumerState<ConsultationStatusScreen> createState() => _ConsultationStatusScreenState();
}

class _ConsultationStatusScreenState extends ConsumerState<ConsultationStatusScreen> with SingleTickerProviderStateMixin {
  int _pendingCount = 0;
  late ScrollController _scrollController;
  late TabController _tabController;
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndSync());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (_isFabVisible) {
        setState(() => _isFabVisible = false);
        ref.read(bottomBarVisibilityProvider.notifier).state = false;
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (!_isFabVisible) {
        setState(() => _isFabVisible = true);
        ref.read(bottomBarVisibilityProvider.notifier).state = true;
      }
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

    final currentIndex = _tabController.index;
    final bgToday = scheme.surface; 
    final bgIncomplete = const Color(0xFFFFF9F2); // 옅은 오렌지빛 (Sand 느낌)
    final bgCalendar = const Color(0xFFF1F8E9); 
    
    final currentBg = currentIndex == 0 ? bgToday : (currentIndex == 1 ? bgIncomplete : bgCalendar);
    final barBg = currentIndex == 0 ? scheme.primary : (currentIndex == 1 ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32));
    final onBar = Colors.white;

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        title: const Text('고객전화'),
        backgroundColor: barBg,
        foregroundColor: onBar,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              if (_tabController.index != 0) {
                _tabController.animateTo(0);
              }
              ref.invalidate(todayStatsProvider);
              ref.invalidate(todayCallsContentProvider);
              ref.invalidate(rankingCallsProvider);
            },
            tooltip: '홈 새로고침',
          ),
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
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.dashboard_rounded, size: 20, color: Colors.amberAccent.shade100),
              text: '요약',
            ),
            Tab(
              icon: Icon(Icons.pending_actions_rounded, size: 20, color: Colors.orangeAccent.shade100),
              text: '미통화',
            ),
            Tab(
              icon: Icon(Icons.calendar_month_rounded, size: 20, color: Colors.greenAccent.shade100),
              text: '달력',
            ),
          ],
          indicatorColor: onBar,
          indicatorWeight: 3,
          labelColor: onBar,
          unselectedLabelColor: onBar.withValues(alpha: 0.65),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                        accountName: Text('${user?.name ?? '사용자'} 님', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        accountEmail: Text('사번/ID: ${user?.id ?? '-'}', style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8))),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          image: DecorationImage(
                            image: const NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
                            repeat: ImageRepeat.repeat,
                            opacity: 0.05,
                          ),
                        ),
                      ),
                      
                      _buildDrawerSectionTitle('상담 관리', scheme),
                      _buildDrawerItem(
                        icon: Icons.pending_actions_rounded,
                        title: '미통화 상담 내역',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SalesCallListScreen(mode: ListQueryMode.incomplete),
                          ));
                        },
                        scheme: scheme,
                      ),
                      _buildDrawerItem(
                        icon: Icons.history_rounded,
                        title: '최근 등록 현황',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SalesCallListScreen(mode: ListQueryMode.recent),
                          ));
                        },
                        scheme: scheme,
                      ),
                      _buildDrawerItem(
                        icon: Icons.list_alt_rounded,
                        title: '전체 상담 목록',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SalesCallListScreen(mode: ListQueryMode.recent), // 전체도 최근순으로 보기
                          ));
                        },
                        scheme: scheme,
                      ),
                      
                      const Divider(indent: 20, endIndent: 20),
                      _buildDrawerSectionTitle('시스템', scheme),
                      _buildDrawerItem(
                        icon: Icons.settings_outlined,
                        title: '설정',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                          );
                        },
                        scheme: scheme,
                      ),
                      
                      const Spacer(),
                      const Divider(),
                      _buildDrawerItem(
                        icon: Icons.logout,
                        title: '로그아웃',
                        color: scheme.error,
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
                        scheme: scheme,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'COAD Sales App v$kAppVersion',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withOpacity(0.5)),
                        ),
                      ),
                    ],
                  ),
                ),
                body: TabBarView(
                  controller: _tabController, // 명시적 연결
                  children: [
                    // 탭 1: 요약 뷰 (심플/간결)
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
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 40),
                          Center(
                            child: Icon(Icons.auto_graph_rounded, size: 48, color: scheme.onSurfaceVariant.withValues(alpha: 0.1)),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              '오늘 하루도 수고 많으십니다!',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 탭 2: 미통화 리스트 (담당자별)
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(rankingCallsProvider);
                        await ref.read(rankingCallsProvider.future);
                      },
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        children: const [
                          _IncompleteBreakdown(),
                        ],
                      ),
                    ),
                    // 탭 3: 미종료 캘린더 뷰
                    _IncompleteCalendar(scrollController: _scrollController),
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
  }


  Widget _buildDrawerSectionTitle(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.primary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ColorScheme scheme,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? scheme.onSecondaryContainer),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color ?? scheme.onSurface,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, size: 20, color: scheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(
                  '오늘 핵심 지표',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Text(
              todayYmdSeoul(),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCardItem(
                label: '금일 접수',
                value: stats.todayCount?.toString() ?? '0',
                icon: Icons.assignment_rounded,
                color: scheme.primary,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesCallListScreen(mode: ListQueryMode.today))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCardItem(
                label: '미통화',
                value: stats.incompleteCount?.toString() ?? '0',
                icon: Icons.pending_rounded,
                color: scheme.error,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesCallListScreen(mode: ListQueryMode.incomplete, date: todayYmdSeoul()))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCardItem(
          label: '오늘 완료된 상담',
          value: stats.completedToday?.toString() ?? '0',
          icon: Icons.check_circle_rounded,
          color: Colors.teal.shade600,
          isWide: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SalesCallListScreen(mode: ListQueryMode.completedToday))),
        ),
      ],
    );
  }
}

class _StatCardItem extends StatefulWidget {
  const _StatCardItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isWide = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isWide;

  @override
  State<_StatCardItem> createState() => _StatCardItemState();
}

class _StatCardItemState extends State<_StatCardItem> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: widget.color.withValues(alpha: 0.08), width: 1.5),
          ),
          padding: EdgeInsets.symmetric(
            vertical: widget.isWide ? 10 : 14,
            horizontal: 16,
          ),
          child: widget.isWide 
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: widget.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.color.withValues(alpha: 0.5))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 20),
                      ),
                      Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
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
    final asyncCalls = ref.watch(rankingCallsProvider);
    final masterAsync = ref.watch(masterDataProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) {
        return masterAsync.when(
          data: (master) {
            final todayStr = todayYmdSeoul();
            final now = DateTime.now();
            final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
            final startOfMonth = DateTime(now.year, now.month, 1);

            // 1. Filter calls
            final filteredCalls = calls.where((c) {
              if (c.callDate == null || c.callDate!.length < 10) return _currentFilter == _SummaryFilter.total;
              final callDt = DateTime.tryParse(c.callDate!.substring(0, 10));
              if (callDt == null) return _currentFilter == _SummaryFilter.total;
              switch (_currentFilter) {
                case _SummaryFilter.today: return c.callDate!.startsWith(todayStr);
                case _SummaryFilter.week: return callDt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && callDt.isBefore(now.add(const Duration(days: 1)));
                case _SummaryFilter.month: return callDt.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
                case _SummaryFilter.total: return true;
              }
            }).toList();

            if (filteredCalls.isEmpty && _currentFilter != _SummaryFilter.total) {
              return _buildEmptyContent(scheme);
            }

            final total = filteredCalls.length;

            // 2. Count per assignee (Initialize with ALL managers from master data)
            final Map<String, int> incompleteCounts = {};
            final Map<String, int> totalCounts = {};
            
            // Extract managers from regions
            for (final r in master.regions) {
              final manager = r.extra['region_manager'];
              if (manager != null && manager.isNotEmpty) {
                incompleteCounts[manager] = 0;
                totalCounts[manager] = 0;
              }
            }
            
            // Add counts from filtered calls
            for (var c in filteredCalls) {
              final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
              totalCounts[a] = (totalCounts[a] ?? 0) + 1;
              if (c.isMissed) {
                incompleteCounts[a] = (incompleteCounts[a] ?? 0) + 1;
              } else {
                // Ensure the manager is in our maps even if not in master regions
                incompleteCounts[a] = incompleteCounts[a] ?? 0;
              }
            }

            final sorted = totalCounts.keys.toList()
              ..sort((a, b) {
                // 1. 미통화 많은 순
                final cmp = (incompleteCounts[b] ?? 0).compareTo(incompleteCounts[a] ?? 0);
                if (cmp != 0) return cmp;
                // 2. 전체 건수 많은 순
                return (totalCounts[b] ?? 0).compareTo(totalCounts[a] ?? 0);
              });

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
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: _SummaryFilter.values.map((filter) {
                    final isSelected = _currentFilter == filter;
                    Color filterColor;
                    String label;
                    
                    switch (filter) {
                      case _SummaryFilter.today: filterColor = scheme.primary; label = '금일'; break;
                      case _SummaryFilter.week: filterColor = scheme.tertiary; label = '금주'; break;
                      case _SummaryFilter.month: filterColor = scheme.secondary; label = '금월'; break;
                      case _SummaryFilter.total: filterColor = scheme.onSurfaceVariant; label = '전체'; break;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _currentFilter = filter);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? filterColor : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              final incomplete = incompleteCounts[name] ?? 0;
              final totalPerManager = totalCounts[name] ?? 0;
              final percent = totalPerManager > 0 ? (totalPerManager - incomplete) / totalPerManager : 1.0;
              
              final rank = idx + 1;
              Color rankColor = scheme.primary;
              if (rank == 1) rankColor = const Color(0xFFD4AF37); // Gold
              else if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
              else if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalesCallListScreen(
                            mode: ListQueryMode.incomplete,
                            initialAssignee: name,
                            date: _currentFilter == _SummaryFilter.today ? todayYmdSeoul() : null,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: rankColor.withValues(alpha: 0.1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: rankColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: rank <= 3 
                                    ? Icon(Icons.workspace_premium_rounded, size: 18, color: rankColor)
                                    : Text('$rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant.withValues(alpha: 0.6))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$incomplete 건',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: incomplete > 0 ? scheme.error : Colors.teal,
                                    ),
                                  ),
                                  Text(
                                    '미통화',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent == 1.0 ? Colors.teal : (percent < 0.5 ? scheme.error : scheme.primary),
                              ),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(percent * 100).toInt()}% 완료',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              ),
                              Text(
                                '총 $totalPerManager 건',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          )),
          error: (e, _) => Center(child: Text('마스터 로드 오류: $e')),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => _ErrorCard(
        message: koreanErrorMessage(e),
        onRetry: () => ref.refresh(rankingCallsProvider),
      ),
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
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) onTap!();
      },
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
  const _IncompleteCalendar({super.key, required this.scrollController});
  final ScrollController scrollController;

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
    final asyncCalls = ref.watch(rankingCallsProvider);
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
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 200), // 압도적인 하단 여백 추가
          children: [
            // ─── 상단 담당자 필터 바 (캘린더용) ───
            Container(
              height: 54,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: sortedAssignees.length,
                itemBuilder: (context, idx) {
                  final assignee = sortedAssignees[idx];
                  final count = counts[assignee] ?? 0;
                  final isSelected = _selectedAssignee == assignee;
                  final color = _colorForAssignee(assignee, scheme);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedAssignee = assignee);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? scheme.onSurface : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ] : [],
                          border: Border.all(
                            color: isSelected ? scheme.onSurface : scheme.outlineVariant.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              assignee,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isSelected ? Colors.white.withValues(alpha: 0.7) : scheme.onSurfaceVariant.withValues(alpha: 0.4),
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3), width: 1.5),
              ),
              padding: const EdgeInsets.all(12),
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
            ],
          );
        },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
    );
  }
}

