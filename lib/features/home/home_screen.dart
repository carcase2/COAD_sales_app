import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/master_data.dart';
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
  late final ScrollController _scrollSummary;
  late final ScrollController _scrollIncomplete;
  late final ScrollController _scrollCalendar;
  late TabController _tabController;
  bool _isFabVisible = true;
  CalendarFormat _launchCalendarFormat = CalendarFormat.month;
  int _calendarKeyNonce = 0;

  @override
  void initState() {
    super.initState();
    _scrollSummary = ScrollController();
    _scrollIncomplete = ScrollController();
    _scrollCalendar = ScrollController();
    _scrollSummary.addListener(_onScroll);
    _scrollIncomplete.addListener(_onScroll);
    _scrollCalendar.addListener(_onScroll);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        // 탭 전환 시 접수 버튼이 사라진 상태로 남지 않도록 복원
        _isFabVisible = true;
      });
    });
    // 탭 진입 시 바가 보이도록 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomBarVisibilityProvider.notifier).state = true;
      _checkAndSync();
      _consumePendingLaunch();
    });
  }

  void _consumePendingLaunch() {
    final next = ref.read(pendingConsultationLaunchProvider);
    if (next == null || !mounted) return;
    setState(() {
      _launchCalendarFormat = next.calendarFormat;
      _calendarKeyNonce++;
    });
    _tabController.animateTo(
      next.tabIndex.clamp(0, 2),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    ref.read(pendingConsultationLaunchProvider.notifier).state = null;
  }

  @override
  void dispose() {
    _scrollSummary.removeListener(_onScroll);
    _scrollIncomplete.removeListener(_onScroll);
    _scrollCalendar.removeListener(_onScroll);
    _scrollSummary.dispose();
    _scrollIncomplete.dispose();
    _scrollCalendar.dispose();
    _tabController.dispose();
    super.dispose();
  }

  ScrollController? _scrollForActiveTab() {
    switch (_tabController.index) {
      case 0:
        return _scrollSummary;
      case 1:
        return _scrollIncomplete;
      case 2:
        return _scrollCalendar;
      default:
        return null;
    }
  }

  void _onScroll() {
    final c = _scrollForActiveTab();
    if (c == null || !c.hasClients) return;
    if (c.offset <= 8) {
      ref.read(bottomBarVisibilityProvider.notifier).state = true;
      return;
    }

    if (c.position.userScrollDirection == ScrollDirection.reverse) {
      ref.read(bottomBarVisibilityProvider.notifier).state = false;
    } else if (c.position.userScrollDirection == ScrollDirection.forward) {
      ref.read(bottomBarVisibilityProvider.notifier).state = true;
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
    ref.listen(pendingConsultationLaunchProvider, (_, __) => _consumePendingLaunch());

    final user = ref.watch(authControllerProvider);
    final statsAsync = ref.watch(todayStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    final currentIndex = _tabController.index;
    final bgToday = scheme.surface;
    final bgIncomplete = Color.alphaBlend(
      scheme.tertiaryContainer.withValues(alpha: 0.22),
      scheme.surface,
    );
    final bgCalendar = Color.alphaBlend(
      scheme.secondaryContainer.withValues(alpha: 0.22),
      scheme.surface,
    );
    
    final currentBg = currentIndex == 0 ? bgToday : (currentIndex == 1 ? bgIncomplete : bgCalendar);
    final barBg = currentIndex == 0
        ? scheme.primary
        : (currentIndex == 1 ? scheme.tertiary : scheme.secondary);
    final onBar = Colors.white;

    return Scaffold(
      backgroundColor: currentBg,
      body: Column(
        children: [
              Container(
                color: barBg,
                child: TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      icon: Icon(
                        Icons.dashboard_rounded,
                        size: 20,
                        color: onBar.withValues(alpha: 0.9),
                      ),
                      text: '요약',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.pending_actions_rounded,
                        size: 20,
                        color: onBar.withValues(alpha: 0.9),
                      ),
                      text: '미통화',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: onBar.withValues(alpha: 0.9),
                      ),
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
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
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
                        controller: _scrollSummary,
                        physics: const AlwaysScrollableScrollPhysics(),
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
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(rankingCallsProvider);
                        await ref.read(rankingCallsProvider.future);
                      },
                      child: SingleChildScrollView(
                        controller: _scrollIncomplete,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        child: const _IncompleteBreakdown(),
                      ),
                    ),
                    _IncompleteCalendar(
                      key: ValueKey(_calendarKeyNonce),
                      scrollController: _scrollCalendar,
                      initialCalendarFormat: _launchCalendarFormat,
                    ),
                  ],
                ),
              ),
        ],
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
                label: '금일 미통화',
                value: stats.incompleteCount?.toString() ?? '0',
                icon: Icons.pending_rounded,
                color: scheme.error,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SalesCallListScreen(
                      mode: ListQueryMode.incomplete,
                      date: todayYmdSeoul(),
                    ),
                  ),
                ),
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
            color: scheme.surfaceContainerLowest,
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
        Widget buildWithMaster(MasterDataBundle? master) {
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
            
            // Extract managers from regions (마스터 로딩 중에는 통화만으로 목록 구성)
            if (master != null) {
              for (final r in master.regions) {
                final manager = r.extra['region_manager'];
                if (manager != null && manager.isNotEmpty) {
                  incompleteCounts[manager] = 0;
                  totalCounts[manager] = 0;
                }
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
                height: 54,
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
                            color: isSelected
                                ? scheme.surfaceContainerLowest
                                : Colors.transparent,
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
                              color: rankColor.withValues(alpha: 0.12),
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
                                      color: incomplete > 0
                                          ? scheme.error
                                          : scheme.secondary,
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
        }

        return masterAsync.when(
          data: (m) => buildWithMaster(m),
          loading: () => buildWithMaster(null),
          error: (_, __) => buildWithMaster(null),
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
  const _IncompleteCalendar({
    super.key,
    required this.scrollController,
    this.initialCalendarFormat = CalendarFormat.month,
  });
  final ScrollController scrollController;
  final CalendarFormat initialCalendarFormat;

  @override
  ConsumerState<_IncompleteCalendar> createState() => _IncompleteCalendarState();
}

class _IncompleteCalendarState extends ConsumerState<_IncompleteCalendar> {
  DateTime _focusedDay = DateTime.now();
  String _selectedAssignee = '전체';
  late CalendarFormat _calendarFormat;

  @override
  void initState() {
    super.initState();
    _calendarFormat = widget.initialCalendarFormat;
  }

  @override
  void didUpdateWidget(_IncompleteCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCalendarFormat != widget.initialCalendarFormat) {
      _calendarFormat = widget.initialCalendarFormat;
    }
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _weekDays(DateTime focusedDay) {
    final start = _dayOnly(focusedDay).subtract(Duration(days: focusedDay.weekday - 1));
    return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
  }

  String _weekdayKo(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  void _jumpToThisMonth() {
    final now = DateTime.now();
    setState(() {
      _calendarFormat = CalendarFormat.month;
      _focusedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _jumpToThisWeek() {
    final now = DateTime.now();
    setState(() {
      _calendarFormat = CalendarFormat.week;
      _focusedDay = DateTime(now.year, now.month, now.day);
    });
  }

  Color _strongColorForAssignee(String assignee) {
    if (assignee == '전체') return Colors.blueGrey.shade700;
    if (assignee == '미지정') return Colors.grey.shade700;
    final colors = [
      Colors.blue.shade700,
      Colors.red.shade700,
      Colors.green.shade700,
      Colors.orange.shade800,
      Colors.purple.shade700,
      Colors.teal.shade700,
      Colors.indigo.shade700,
    ];
    return colors[assignee.hashCode.abs() % colors.length];
  }

  String _calendarAssignee(SalesCall c) {
    final manager = (c.regionManager ?? '').trim();
    if (manager.isNotEmpty) return manager;
    return '미지정';
  }

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(calendarFollowCallsProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) {
        // 날짜 팔로우: 미종료(status_id NOT IN 2,3,4) + next_scheduled_date 있음 (접수일과 무관)
        final followCalls = calls
            .where((c) => ![2, 3, 4].contains(c.statusId) && c.followCalendarDateKey != null)
            .toList();

        final focusedYear = _focusedDay.year;
        final focusedMonth = _focusedDay.month;
        final focusedMonthStr = "$focusedYear-${focusedMonth.toString().padLeft(2, '0')}";
        final weekStart = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day)
            .subtract(Duration(days: _focusedDay.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));

        bool inFocusedPeriod(String? followYmd) {
          if (followYmd == null || followYmd.length < 10) return false;
          if (_calendarFormat == CalendarFormat.month) {
            return followYmd.startsWith(focusedMonthStr);
          }
          final dt = DateTime.tryParse(followYmd.substring(0, 10));
          if (dt == null) return false;
          final dayOnly = DateTime(dt.year, dt.month, dt.day);
          return !dayOnly.isBefore(weekStart) && !dayOnly.isAfter(weekEnd);
        }

        final visibleCallsInPeriod = followCalls.where((c) => inFocusedPeriod(c.followCalendarDateKey)).toList();

        final Map<String, int> counts = {'전체': visibleCallsInPeriod.length};
        for (var c in visibleCallsInPeriod) {
          final a = _calendarAssignee(c);
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

        // 담당자별 색상 충돌 방지: 화면 내 팔레트 맵을 고정 생성
        final palette = <Color>[
          Colors.blue.shade700,
          Colors.red.shade700,
          Colors.green.shade700,
          Colors.orange.shade800,
          Colors.purple.shade700,
          Colors.teal.shade700,
          Colors.indigo.shade700,
          Colors.pink.shade700,
          Colors.cyan.shade700,
          Colors.brown.shade700,
        ];
        final assigneeColorMap = <String, Color>{};
        var paletteIdx = 0;
        for (final a in sortedAssignees) {
          if (a == '전체') {
            assigneeColorMap[a] = Colors.blueGrey.shade700;
            continue;
          }
          if (a == '미지정') {
            assigneeColorMap[a] = Colors.grey.shade700;
            continue;
          }
          assigneeColorMap[a] = palette[paletteIdx % palette.length];
          paletteIdx += 1;
        }
        Color colorForAssignee(String name) =>
            assigneeColorMap[name] ?? _strongColorForAssignee(name);

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
        for (final c in followCalls) {
          final a = _calendarAssignee(c);
          if (_selectedAssignee != '전체' && a != _selectedAssignee) continue;

          final fk = c.followCalendarDateKey;
          if (fk != null) {
            dateMarkers[fk] = (dateMarkers[fk] ?? 0) + 1;
          }
        }

        final weekDays = _weekDays(_focusedDay);
        final Map<String, Map<String, int>> weekAssigneeCounts = {};
        for (final day in weekDays) {
          weekAssigneeCounts[day.toIso8601String().substring(0, 10)] = <String, int>{};
        }
        for (final c in followCalls) {
          final fk = c.followCalendarDateKey;
          if (fk == null || fk.length < 10) continue;
          final dateKey = fk.substring(0, 10);
          final bucket = weekAssigneeCounts[dateKey];
          if (bucket == null) continue;
          final assignee = _calendarAssignee(c);
          if (_selectedAssignee != '전체' && assignee != _selectedAssignee) continue;
          bucket[assignee] = (bucket[assignee] ?? 0) + 1;
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(calendarFollowCallsProvider);
            await ref.read(calendarFollowCallsProvider.future);
          },
          child: ListView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 200), // 압도적인 하단 여백 추가
          children: [
            // ─── 상단 담당자 필터 바 (캘린더용) ───
            Container(
              height: 52,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: sortedAssignees.length,
                itemBuilder: (context, idx) {
                  final assignee = sortedAssignees[idx];
                  final count = counts[assignee] ?? 0;
                  final isSelected = _selectedAssignee == assignee;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedAssignee = assignee);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _strongColorForAssignee(assignee).withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: _strongColorForAssignee(assignee).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ] : [],
                          border: Border.all(
                            color: isSelected
                                ? _strongColorForAssignee(assignee).withValues(alpha: 0.45)
                                : scheme.outlineVariant.withValues(alpha: 0.3),
                            width: isSelected ? 1.6 : 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorForAssignee(assignee),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              assignee,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorForAssignee(assignee),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorForAssignee(assignee)
                                    : colorForAssignee(assignee).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : colorForAssignee(assignee),
                                ),
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
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _calendarFormat = CalendarFormat.month),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _calendarFormat == CalendarFormat.month
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _calendarFormat == CalendarFormat.month
                                      ? Colors.indigo.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                ),
                                boxShadow: _calendarFormat == CalendarFormat.month
                                    ? [
                                        BoxShadow(
                                          color: Colors.indigo.withValues(alpha: 0.16),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 14,
                                    color: _calendarFormat == CalendarFormat.month
                                        ? Colors.indigo
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '월간 달력',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _calendarFormat == CalendarFormat.month
                                          ? Colors.indigo
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _calendarFormat = CalendarFormat.week),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _calendarFormat == CalendarFormat.week
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _calendarFormat == CalendarFormat.week
                                      ? Colors.teal.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                ),
                                boxShadow: _calendarFormat == CalendarFormat.week
                                    ? [
                                        BoxShadow(
                                          color: Colors.teal.withValues(alpha: 0.16),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.view_week_rounded,
                                    size: 14,
                                    color: _calendarFormat == CalendarFormat.week
                                        ? Colors.teal
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '주간 달력',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _calendarFormat == CalendarFormat.week
                                          ? Colors.teal
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _calendarFormat == CalendarFormat.month ? _jumpToThisMonth : _jumpToThisWeek,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: (_calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _calendarFormat == CalendarFormat.month ? '이번달' : '이번주',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
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
                  calendarFormat: _calendarFormat,
                  locale: 'ko_KR',
                  daysOfWeekHeight: 40,
                  rowHeight: 52,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekendStyle: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    holidayTextStyle: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final txt = _weekdayKo(day.weekday);
                      Color color = scheme.onSurfaceVariant;
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent;
                      return Center(
                        child: Text(
                          txt,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      Color color = scheme.onSurface;
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent;
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                        ),
                      );
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      Color color = scheme.onSurfaceVariant.withValues(alpha: 0.45);
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent.withValues(alpha: 0.5);
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent.withValues(alpha: 0.5);
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
                        ),
                      );
                    },
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
            if (_calendarFormat == CalendarFormat.week) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.view_week_rounded, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          '주간 상세',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...weekDays.map((day) {
                      final dateKey = day.toIso8601String().substring(0, 10);
                      final dayMap = weekAssigneeCounts[dateKey] ?? const <String, int>{};
                      final total = dayMap.values.fold<int>(0, (sum, v) => sum + v);
                      final sorted = dayMap.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final isToday = _dayOnly(day) == _dayOnly(DateTime.now());

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SalesCallListScreen(
                                mode: ListQueryMode.incompleteByDate,
                                date: dateKey,
                                initialAssignee: _selectedAssignee,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: isToday ? scheme.primaryContainer.withValues(alpha: 0.25) : scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday ? scheme.primary.withValues(alpha: 0.45) : scheme.outlineVariant.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 68,
                                child: Text(
                                  '${day.month}/${day.day} (${_weekdayKo(day.weekday)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: total == 0
                                    ? Text(
                                        '데이터 없음',
                                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: sorted
                                            .map(
                                              (e) => Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(10),
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) => SalesCallListScreen(
                                                          mode: ListQueryMode.incompleteByDate,
                                                          date: dateKey,
                                                          initialAssignee: e.key,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: colorForAssignee(e.key).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '${e.key} ${e.value}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: colorForAssignee(e.key),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '$total건',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: scheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            ],
          ),
        );
        },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
    );
  }
}

