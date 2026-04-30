import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHubScreen extends ConsumerStatefulWidget {
  const HomeHubScreen({super.key});

  @override
  ConsumerState<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends ConsumerState<HomeHubScreen> {
  late ScrollController _scrollController;
  bool _isBottomBarVisible = true;
  static const int _followPickerFetchLimit = 1000;
  static const int _incompletePickerFetchLimit = 1000;

  String _formatMinutes(double? minutes) {
    if (minutes == null) return '-';
    if (minutes < 1) return '1분 미만';
    if (minutes < 60) return '${minutes.round()}분';
    final h = (minutes ~/ 60);
    final m = (minutes % 60).round();
    if (m == 0) return '${h}시간';
    return '${h}시간 ${m}분';
  }

  Future<void> _openTodayFollowPicker() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    List<dynamic> rows;
    try {
      rows = await repo.fetchCalls(
        followDate: todayYmdSeoul(),
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        limit: _followPickerFetchLimit,
        includeCallHistory: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로우 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    final Map<String, int> counts = {'전체': rows.length};
    final isTruncated = rows.length >= _followPickerFetchLimit;
    for (final row in rows) {
      final assignee = (row.assignedTo == null || row.assignedTo!.isEmpty) ? '미지정' : row.assignedTo!;
      counts[assignee] = (counts[assignee] ?? 0) + 1;
    }
    final loginName = ref.read(authControllerProvider)?.name;
    final defaultAssignee = (loginName != null && counts.containsKey(loginName)) ? loginName : '전체';

    final assignees = counts.keys.toList()
      ..sort((a, b) {
        if (a == '전체') return -1;
        if (b == '전체') return 1;
        if (a == defaultAssignee) return -1;
        if (b == defaultAssignee) return 1;
        final countA = counts[a] ?? 0;
        final countB = counts[b] ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '날짜 팔로우 담당자 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${todayYmdSeoul()} 기준',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (isTruncated) ...[
                  const SizedBox(height: 4),
                  Text(
                    '상위 $_followPickerFetchLimit건 기준으로 집계됩니다.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.error.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pop(defaultAssignee),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text('기본 선택: $defaultAssignee'),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assignees.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    itemBuilder: (context, index) {
                      final assignee = assignees[index];
                      final count = counts[assignee] ?? 0;
                      final isDefault = assignee == defaultAssignee;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(assignee),
                        leading: Icon(
                          assignee == '전체' ? Icons.people_alt_rounded : Icons.person_rounded,
                          color: scheme.primary,
                        ),
                        title: Text(
                          assignee,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: isDefault
                            ? Text(
                                '로그인 기본 담당자',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count건',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incompleteByDate,
          date: todayYmdSeoul(),
          initialAssignee: selected,
        ),
      ),
    );
  }

  Future<void> _openTodayIncompletePicker() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    List<dynamic> rows;
    try {
      rows = await repo.fetchCalls(
        date: todayYmdSeoul(),
        uncalledOnly: true,
        limit: _incompletePickerFetchLimit,
        includeCallHistory: false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미통화 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    final Map<String, int> counts = {'전체': rows.length};
    final isTruncated = rows.length >= _incompletePickerFetchLimit;
    for (final row in rows) {
      final assignee = (row.assignedTo == null || row.assignedTo!.isEmpty)
          ? '미지정'
          : row.assignedTo!;
      counts[assignee] = (counts[assignee] ?? 0) + 1;
    }
    final loginName = ref.read(authControllerProvider)?.name;
    final defaultAssignee =
        (loginName != null && counts.containsKey(loginName)) ? loginName : '전체';

    final assignees = counts.keys.toList()
      ..sort((a, b) {
        if (a == '전체') return -1;
        if (b == '전체') return 1;
        if (a == defaultAssignee) return -1;
        if (b == defaultAssignee) return 1;
        final countA = counts[a] ?? 0;
        final countB = counts[b] ?? 0;
        if (countA != countB) return countB.compareTo(countA);
        return a.compareTo(b);
      });

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘 미통화 담당자 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${todayYmdSeoul()} 기준',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (isTruncated) ...[
                  const SizedBox(height: 4),
                  Text(
                    '상위 $_incompletePickerFetchLimit건 기준으로 집계됩니다.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.error.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).pop(defaultAssignee),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text('기본 선택: $defaultAssignee'),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assignees.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final assignee = assignees[index];
                      final count = counts[assignee] ?? 0;
                      final isDefault = assignee == defaultAssignee;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(assignee),
                        leading: Icon(
                          assignee == '전체'
                              ? Icons.people_alt_rounded
                              : Icons.person_rounded,
                          color: scheme.primary,
                        ),
                        title: Text(
                          assignee,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: isDefault
                            ? Text(
                                '로그인 기본 담당자',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count건',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incomplete,
          date: todayYmdSeoul(),
          initialAssignee: selected,
        ),
      ),
    );
  }

  Future<void> _openTodayQualityPicker({required bool forUncalledRate}) async {
    CallQualityOverview overview;
    try {
      overview = await ref.read(todayCallQualityOverviewProvider.future);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('품질 지표를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;

    final byAssignee = overview.byAssignee;
    final Map<String, AssigneeQualityMetric> metricMap = {
      for (final m in byAssignee) m.assignee: m,
      '전체': AssigneeQualityMetric(
        assignee: '전체',
        total: overview.total,
        uncalled: overview.uncalled,
        uncalledRate: overview.uncalledRate,
        avgFirstResponseMinutes: overview.avgFirstResponseMinutes,
      ),
    };
    final loginName = ref.read(authControllerProvider)?.name;
    final defaultAssignee =
        (loginName != null && metricMap.containsKey(loginName)) ? loginName : '전체';
    final assignees = metricMap.keys.toList()
      ..sort((a, b) {
        if (a == '전체') return -1;
        if (b == '전체') return 1;
        if (a == defaultAssignee) return -1;
        if (b == defaultAssignee) return 1;
        final totalA = metricMap[a]?.total ?? 0;
        final totalB = metricMap[b]?.total ?? 0;
        if (totalA != totalB) return totalB.compareTo(totalA);
        return a.compareTo(b);
      });

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forUncalledRate ? '금일 미통화 비율' : '금일 초기응답 평균시간',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${todayYmdSeoul()} 기준',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assignees.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final assignee = assignees[index];
                      final metric = metricMap[assignee]!;
                      final valueText = forUncalledRate
                          ? '${(metric.uncalledRate * 100).toStringAsFixed(1)}%'
                          : _formatMinutes(metric.avgFirstResponseMinutes);
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(assignee),
                        leading: Icon(
                          assignee == '전체'
                              ? Icons.people_alt_rounded
                              : Icons.person_rounded,
                          color: scheme.primary,
                        ),
                        title: Text(
                          assignee,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '총 ${metric.total}건',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            valueText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: forUncalledRate ? ListQueryMode.incomplete : ListQueryMode.today,
          date: todayYmdSeoul(),
          initialAssignee: selected,
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // 탭 진입 시 바가 보이도록 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomBarVisibilityProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      if (_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = false);
        ref.read(bottomBarVisibilityProvider.notifier).state = false;
      }
    } else if (direction == ScrollDirection.forward) {
      if (!_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
        ref.read(bottomBarVisibilityProvider.notifier).state = true;
      }
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(todayStatsProvider);
    ref.invalidate(todayFollowOverviewProvider);
    ref.invalidate(todayCallQualityOverviewProvider);
    await Future.wait([
      ref.read(todayStatsProvider.future),
      ref.read(todayFollowOverviewProvider.future),
      ref.read(todayCallQualityOverviewProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(todayStatsProvider);
    final followOverviewAsync = ref.watch(todayFollowOverviewProvider);
    final qualityAsync = ref.watch(todayCallQualityOverviewProvider);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
        // ─── 상단 배경 헤더 (Global AppBar가 있으므로 배경 역할만 수행) ───
        SliverToBoxAdapter(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
        ),
        
        // ─── 본문 영역 ───
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(user?.name, scheme),
                const SizedBox(height: 20),

                // ─── 미니 대시보드 (현황 요약) ───
                Text(
                  '오늘의 흐름',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                statsAsync.when(
                  data: (s) {
                    final todayFollowCount = followOverviewAsync.valueOrNull?.total ?? 0;
                    final quality = qualityAsync.valueOrNull;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniStatsWidget(
                          today: s.todayCount ?? 0,
                          incomplete: s.incompleteCount ?? 0,
                          todayFollow: todayFollowCount,
                          uncalledRateText: quality == null
                              ? '-'
                              : '${(quality.uncalledRate * 100).toStringAsFixed(1)}%',
                          avgFirstResponseText: quality == null
                              ? '-'
                              : _formatMinutes(quality.avgFirstResponseMinutes),
                          onTapToday: () {
                            final loginAssignee = user?.name?.trim();
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SalesCallListScreen(
                                  mode: ListQueryMode.today,
                                  initialAssignee: (loginAssignee == null ||
                                          loginAssignee.isEmpty)
                                      ? null
                                      : loginAssignee,
                                ),
                              ),
                            );
                          },
                          onTapIncomplete: () {
                            _openTodayIncompletePicker();
                          },
                          onTapTodayFollow: () {
                            _openTodayFollowPicker();
                          },
                          onTapUncalledRate: () {
                            _openTodayQualityPicker(forUncalledRate: true);
                          },
                          onTapFirstResponse: () {
                            _openTodayQualityPicker(forUncalledRate: false);
                          },
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String? name, ColorScheme scheme) {
    final today = todayYmdSeoul();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${name ?? '사용자'}님, 오늘 현황입니다',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                today,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '핵심 지표를 먼저 확인하고 바로 실행하세요.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _MiniStatsWidget extends StatelessWidget {
  const _MiniStatsWidget({
    required this.today,
    required this.incomplete,
    required this.todayFollow,
    required this.uncalledRateText,
    required this.avgFirstResponseText,
    required this.onTapToday,
    required this.onTapIncomplete,
    required this.onTapTodayFollow,
    required this.onTapUncalledRate,
    required this.onTapFirstResponse,
  });

  final int today;
  final int incomplete;
  final int todayFollow;
  final String uncalledRateText;
  final String avgFirstResponseText;
  final VoidCallback onTapToday;
  final VoidCallback onTapIncomplete;
  final VoidCallback onTapTodayFollow;
  final VoidCallback onTapUncalledRate;
  final VoidCallback onTapFirstResponse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapToday,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _StatItem(
                      label: '금일 접수',
                      value: today.toString(),
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: scheme.primary.withValues(alpha: 0.1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapIncomplete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _StatItem(
                      label: '금일 미통화',
                      value: incomplete.toString(),
                      color: scheme.error,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: scheme.primary.withValues(alpha: 0.1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTapTodayFollow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _StatItem(
                      label: '오늘 팔로우',
                      value: todayFollow.toString(),
                      color: scheme.tertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InsightItem(
                  label: '미통화 비율',
                  value: uncalledRateText,
                  color: scheme.error,
                  onTap: onTapUncalledRate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InsightItem(
                  label: '초기응답 평균',
                  value: avgFirstResponseText,
                  color: scheme.secondary,
                  onTap: onTapFirstResponse,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

