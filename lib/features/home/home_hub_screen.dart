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

  void _openTodayFollowForAssignee(String assignee) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incompleteByDate,
          date: todayYmdSeoul(),
          initialAssignee: assignee,
        ),
      ),
    );
  }

  void _openTodayIncompleteForAssignee(String assignee) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incomplete,
          date: todayYmdSeoul(),
          initialAssignee: assignee,
        ),
      ),
    );
  }

  /// 홈 하단: 왼쪽 미통화 / 오른쪽 팔로우 (가로 2열)
  Widget _buildTwinAssigneeColumns({
    required ColorScheme scheme,
    required AsyncValue<AssigneeOverview> incompleteAsync,
    required AsyncValue<AssigneeOverview> followAsync,
  }) {
    Widget columnShell({
      required String title,
      required AsyncValue<AssigneeOverview> async,
      required String emptyMessage,
      required Color accent,
      required void Function(String assignee) onAssigneeTap,
    }) {
      return async.when(
        data: (overview) => _buildAssigneeHalfColumn(
          scheme: scheme,
          title: title,
          emptyMessage: emptyMessage,
          overview: overview,
          accent: accent,
          onAssigneeTap: onAssigneeTap,
        ),
        loading: () => _buildAssigneeHalfColumnLoading(scheme),
        error: (_, _) => _buildAssigneeHalfColumnError(scheme),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          '담당자별',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: columnShell(
                title: '오늘 미통화',
                async: incompleteAsync,
                emptyMessage: '없음',
                accent: scheme.error,
                onAssigneeTap: _openTodayIncompleteForAssignee,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: columnShell(
                title: '오늘 팔로우',
                async: followAsync,
                emptyMessage: '없음',
                accent: Colors.deepPurple,
                onAssigneeTap: _openTodayFollowForAssignee,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssigneeHalfColumnLoading(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  Widget _buildAssigneeHalfColumnError(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Text(
        '불러오기 실패',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.error.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _buildAssigneeHalfColumn({
    required ColorScheme scheme,
    required String title,
    required String emptyMessage,
    required AssigneeOverview overview,
    required Color accent,
    required void Function(String assignee) onAssigneeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 8),
        if (overview.byAssignee.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < overview.byAssignee.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.vertical(
                        top: i == 0 ? const Radius.circular(14) : Radius.zero,
                        bottom: i == overview.byAssignee.length - 1 ? const Radius.circular(14) : Radius.zero,
                      ),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAssigneeTap(overview.byAssignee[i].assignee);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                overview.byAssignee[i].assignee,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${overview.byAssignee[i].count}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                  color: accent is MaterialColor ? accent.shade700 : accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
      ],
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
    ref.invalidate(todayIncompleteOverviewProvider);
    await Future.wait([
      ref.read(todayStatsProvider.future),
      ref.read(todayFollowOverviewProvider.future),
      ref.read(todayIncompleteOverviewProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(todayStatsProvider);
    final followOverviewAsync = ref.watch(todayFollowOverviewProvider);
    final incompleteOverviewAsync = ref.watch(todayIncompleteOverviewProvider);

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
                const SizedBox(height: 32),

                // ─── 미니 대시보드 (현황 요약) ───
                Text(
                  '오늘의 흐름',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),
                statsAsync.when(
                  data: (s) {
                    final todayFollowCount = followOverviewAsync.valueOrNull?.total ?? 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniStatsWidget(
                          today: s.todayCount ?? 0,
                          incomplete: s.incompleteCount ?? 0,
                          todayFollow: todayFollowCount,
                          onTapToday: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SalesCallListScreen(mode: ListQueryMode.today),
                              ),
                            );
                          },
                          onTapIncomplete: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SalesCallListScreen(
                                  mode: ListQueryMode.incomplete,
                                  date: todayYmdSeoul(),
                                ),
                              ),
                            );
                          },
                          onTapTodayFollow: () {
                            _openTodayFollowPicker();
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildTwinAssigneeColumns(
                          scheme: scheme,
                          incompleteAsync: incompleteOverviewAsync,
                          followAsync: followOverviewAsync,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${name ?? '사용자'}님,',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '반가워요! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '오늘도 스마트한 영업을 COAD가 응원합니다.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: -0.3,
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
    required this.onTapToday,
    required this.onTapIncomplete,
    required this.onTapTodayFollow,
  });

  final int today;
  final int incomplete;
  final int todayFollow;
  final VoidCallback onTapToday;
  final VoidCallback onTapIncomplete;
  final VoidCallback onTapTodayFollow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTapToday,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _StatItem(label: '금일 접수', value: today.toString(), color: scheme.primary),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: scheme.primary.withValues(alpha: 0.1)),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTapIncomplete,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _StatItem(label: '금일 미통화', value: incomplete.toString(), color: scheme.error),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: scheme.primary.withValues(alpha: 0.1)),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTapTodayFollow,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _StatItem(label: '달력 오늘 팔로우', value: todayFollow.toString(), color: Colors.deepPurple),
              ),
            ),
          ),
        ],
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -1),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

