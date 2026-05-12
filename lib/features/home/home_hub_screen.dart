import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 상단 ◀▶ 이동 단위 (일 / 주 / 월).
enum HubNavStep { day, week, month }

class HomeHubScreen extends ConsumerStatefulWidget {
  const HomeHubScreen({super.key});

  @override
  ConsumerState<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends ConsumerState<HomeHubScreen> {
  late ScrollController _scrollController;
  late String _hubFlowAnchorYmd;
  HubNavStep _hubNavStep = HubNavStep.day;
  bool _isBottomBarVisible = true;
  static const int _followPickerFetchLimit = 1000;
  static const int _incompletePickerFetchLimit = 1000;

  HubPeriodKey get _dayKey =>
      (period: HubPeriod.day, anchorYmd: _hubFlowAnchorYmd);

  HubPeriodKey get _weekKey =>
      (period: HubPeriod.week, anchorYmd: _hubFlowAnchorYmd);

  HubPeriodKey get _monthKey =>
      (period: HubPeriod.month, anchorYmd: _hubFlowAnchorYmd);

  /// 현재 탭 기준으로 앵커를 이동: 일→오늘, 주→이번 주(월요일), 월→이번 달 1일. 탭은 유지한다.
  void _resetHubFlowAnchorToCurrent() {
    final today = todayYmdSeoul();
    setState(() {
      _hubFlowAnchorYmd = switch (_hubNavStep) {
        HubNavStep.day => today,
        HubNavStep.week => seoulWeekRangeContaining(today).$1,
        HubNavStep.month => firstDayOfMonthYmd(today),
      };
    });
  }

  bool _isHubFlowOnCurrentPeriod() {
    final today = todayYmdSeoul();
    switch (_hubNavStep) {
      case HubNavStep.day:
        return _hubFlowAnchorYmd == today;
      case HubNavStep.week:
        final curMon = seoulWeekRangeContaining(_hubFlowAnchorYmd).$1;
        final thisMon = seoulWeekRangeContaining(today).$1;
        return curMon == thisMon;
      case HubNavStep.month:
        return firstDayOfMonthYmd(_hubFlowAnchorYmd) ==
            firstDayOfMonthYmd(today);
    }
  }

  String _hubResetShortcutLabel() {
    return switch (_hubNavStep) {
      HubNavStep.day => '오늘로',
      HubNavStep.week => '금주로',
      HubNavStep.month => '금월로',
    };
  }

  void _shiftHubNav(int dir) {
    final today = todayYmdSeoul();
    switch (_hubNavStep) {
      case HubNavStep.day:
        final next = addDaysToYmd(_hubFlowAnchorYmd, dir);
        if (next.compareTo(today) > 0) return;
        setState(() => _hubFlowAnchorYmd = next);
        return;
      case HubNavStep.week:
        final mon = seoulWeekRangeContaining(_hubFlowAnchorYmd).$1;
        final nextMon = addDaysToYmd(mon, 7 * dir);
        if (nextMon.compareTo(today) > 0) return;
        setState(() => _hubFlowAnchorYmd = nextMon);
        return;
      case HubNavStep.month:
        final curFirst = firstDayOfMonthYmd(_hubFlowAnchorYmd);
        final nextFirst = addCalendarMonthsFirstOfMonth(curFirst, dir);
        if (nextFirst.compareTo(firstDayOfMonthYmd(today)) > 0) return;
        setState(() => _hubFlowAnchorYmd = nextFirst);
        return;
    }
  }

  bool _canShiftHubNavNewer() {
    final today = todayYmdSeoul();
    switch (_hubNavStep) {
      case HubNavStep.day:
        return _hubFlowAnchorYmd.compareTo(today) < 0;
      case HubNavStep.week:
        final mon = seoulWeekRangeContaining(_hubFlowAnchorYmd).$1;
        final nextMon = addDaysToYmd(mon, 7);
        return nextMon.compareTo(today) <= 0;
      case HubNavStep.month:
        final nextFirst = addCalendarMonthsFirstOfMonth(_hubFlowAnchorYmd, 1);
        return nextFirst.compareTo(firstDayOfMonthYmd(today)) <= 0;
    }
  }

  String _hubNavCenterLabel() {
    switch (_hubNavStep) {
      case HubNavStep.day:
        return formatYmdFlowLabelKo(_hubFlowAnchorYmd);
      case HubNavStep.week:
        final w = seoulWeekRangeContaining(_hubFlowAnchorYmd);
        return '금주 · ${formatWeekRangeFlowLabel(w.$1, w.$2)}';
      case HubNavStep.month:
        return '금월 · ${formatYearMonthLabelKo(_hubFlowAnchorYmd)}';
    }
  }

  Widget _buildHubFlowDateBar(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<HubNavStep>(
          segments: const [
            ButtonSegment(
              value: HubNavStep.day,
              label: Text('일'),
              icon: Icon(Icons.calendar_today_rounded, size: 16),
            ),
            ButtonSegment(
              value: HubNavStep.week,
              label: Text('주'),
              icon: Icon(Icons.date_range_rounded, size: 16),
            ),
            ButtonSegment(
              value: HubNavStep.month,
              label: Text('월'),
              icon: Icon(Icons.calendar_month_rounded, size: 16),
            ),
          ],
          selected: {_hubNavStep},
          onSelectionChanged: (s) {
            if (s.isEmpty) return;
            final next = s.first;
            setState(() {
              _hubNavStep = next;
              final today = todayYmdSeoul();
              _hubFlowAnchorYmd = switch (next) {
                HubNavStep.day => today,
                HubNavStep.week => seoulWeekRangeContaining(today).$1,
                HubNavStep.month => firstDayOfMonthYmd(today),
              };
            });
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return scheme.onSecondaryContainer;
              }
              return scheme.onSurfaceVariant;
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: () => _shiftHubNav(-1),
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: switch (_hubNavStep) {
                HubNavStep.day => '이전 날',
                HubNavStep.week => '이전 주',
                HubNavStep.month => '이전 달',
              },
            ),
            Expanded(
              child: Text(
                _hubNavCenterLabel(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1.25,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: _canShiftHubNavNewer()
                  ? () => _shiftHubNav(1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: switch (_hubNavStep) {
                HubNavStep.day => '다음 날',
                HubNavStep.week => '다음 주',
                HubNavStep.month => '다음 달',
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHubFlowResetButton(ColorScheme scheme) {
    final enabled = !_isHubFlowOnCurrentPeriod();
    final label = _hubResetShortcutLabel();
    final icon = switch (_hubNavStep) {
      HubNavStep.day => Icons.today_rounded,
      HubNavStep.week => Icons.view_week_rounded,
      HubNavStep.month => Icons.calendar_view_month_rounded,
    };
    final tip = switch (_hubNavStep) {
      HubNavStep.day => '기준 날짜를 오늘로 맞춥니다',
      HubNavStep.week => '이번 주(금주)로 이동합니다',
      HubNavStep.month => '이번 달(금월)로 이동합니다',
    };

    return Tooltip(
      message: tip,
      child: FilledButton.tonalIcon(
        onPressed: enabled ? _resetHubFlowAnchorToCurrent : null,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: enabled
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          backgroundColor: enabled
              ? scheme.secondaryContainer.withValues(alpha: 0.85)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        ),
      ),
    );
  }

  String _formatMinutes(double? minutes) {
    if (minutes == null) return '-';
    if (minutes < 1) return '1분 미만';
    if (minutes < 60) return '${minutes.round()}분';
    final h = (minutes ~/ 60);
    final m = (minutes % 60).round();
    if (m == 0) return '${h}시간';
    return '${h}시간${m}분';
  }

  String _regionAssigneeOf(dynamic row) {
    final manager = (row.regionManager ?? '').toString().trim();
    if (manager.isNotEmpty) return manager;
    return '미지정';
  }

  Future<void> _openFollowPicker(HubPeriod scope) async {
    final repo = ref.read(salesCallsRepositoryProvider);
    List<dynamic> rows;
    try {
      switch (scope) {
        case HubPeriod.day:
          rows = await repo.fetchCalls(
            followDate: _hubFlowAnchorYmd,
            incompleteOnly: true,
            excludeSimpleInquiries: true,
            limit: _followPickerFetchLimit,
            includeCallHistory: false,
          );
        case HubPeriod.week:
          final w = seoulWeekRangeContaining(_hubFlowAnchorYmd);
          rows = await repo.fetchCalls(
            followRangeStart: w.$1,
            followRangeEndInclusive: w.$2,
            incompleteOnly: true,
            excludeSimpleInquiries: true,
            limit: _followPickerFetchLimit,
            includeCallHistory: false,
          );
        case HubPeriod.month:
          final m = seoulMonthRangeContaining(_hubFlowAnchorYmd);
          rows = await repo.fetchCalls(
            followRangeStart: m.$1,
            followRangeEndInclusive: m.$2,
            incompleteOnly: true,
            excludeSimpleInquiries: true,
            limit: _followPickerFetchLimit,
            includeCallHistory: false,
          );
      }
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
      final assignee = _regionAssigneeOf(row);
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

    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthR = seoulMonthRangeContaining(_hubFlowAnchorYmd);

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
                  switch (scope) {
                    HubPeriod.day => '${_hubFlowAnchorYmd} 기준',
                    HubPeriod.week =>
                      '${formatWeekRangeFlowLabel(weekR.$1, weekR.$2)} 주간 기준',
                    HubPeriod.month =>
                      '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} 팔로우 기준',
                  },
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

    switch (scope) {
      case HubPeriod.day:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.incompleteByDate,
              date: _hubFlowAnchorYmd,
              initialAssignee: selected,
            ),
          ),
        );
      case HubPeriod.week:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.followRange,
              date: weekR.$1,
              dateEndInclusive: weekR.$2,
              initialAssignee: selected,
            ),
          ),
        );
      case HubPeriod.month:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.followRange,
              date: monthR.$1,
              dateEndInclusive: monthR.$2,
              initialAssignee: selected,
            ),
          ),
        );
    }
  }

  Future<void> _openIncompletePicker(HubPeriod scope) async {
    final repo = ref.read(salesCallsRepositoryProvider);
    List<dynamic> rows;
    try {
      switch (scope) {
        case HubPeriod.day:
          rows = await repo.fetchCalls(
            date: _hubFlowAnchorYmd,
            uncalledOnly: true,
            limit: _incompletePickerFetchLimit,
            includeCallHistory: false,
          );
        case HubPeriod.week:
          final w = seoulWeekRangeContaining(_hubFlowAnchorYmd);
          rows = await repo.fetchCalls(
            dateRangeStart: w.$1,
            dateRangeEndInclusive: w.$2,
            uncalledOnly: true,
            limit: _incompletePickerFetchLimit,
            includeCallHistory: false,
          );
        case HubPeriod.month:
          final m = seoulMonthRangeContaining(_hubFlowAnchorYmd);
          rows = await repo.fetchCalls(
            dateRangeStart: m.$1,
            dateRangeEndInclusive: m.$2,
            uncalledOnly: true,
            limit: _incompletePickerFetchLimit,
            includeCallHistory: false,
          );
      }
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

    final weekRi = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthRi = seoulMonthRangeContaining(_hubFlowAnchorYmd);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        void pushIncompleteList(String assignee) {
          switch (scope) {
            case HubPeriod.day:
              Navigator.of(sheetContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => SalesCallListScreen(
                    mode: ListQueryMode.incomplete,
                    date: _hubFlowAnchorYmd,
                    initialAssignee: assignee,
                  ),
                ),
              );
            case HubPeriod.week:
              Navigator.of(sheetContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => SalesCallListScreen(
                    mode: ListQueryMode.incomplete,
                    date: weekRi.$1,
                    dateEndInclusive: weekRi.$2,
                    initialAssignee: assignee,
                  ),
                ),
              );
            case HubPeriod.month:
              Navigator.of(sheetContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => SalesCallListScreen(
                    mode: ListQueryMode.incomplete,
                    date: monthRi.$1,
                    dateEndInclusive: monthRi.$2,
                    initialAssignee: assignee,
                  ),
                ),
              );
          }
        }

        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '미통화 담당자 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (scope) {
                    HubPeriod.day => '${_hubFlowAnchorYmd} 기준',
                    HubPeriod.week =>
                      '${formatWeekRangeFlowLabel(weekRi.$1, weekRi.$2)} 주간 기준',
                    HubPeriod.month =>
                      '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} 기준',
                  },
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
                    onPressed: () => pushIncompleteList(defaultAssignee),
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
                        onTap: () => pushIncompleteList(assignee),
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
  }

  Future<void> _openQualityPicker({
    required bool forUncalledRate,
    required HubPeriod scope,
  }) async {
    final periodKey = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    CallQualityOverview overview;
    try {
      overview =
          await ref.read(hubPeriodQualityOverviewProvider(periodKey).future);
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

    final weekRq = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthRq = seoulMonthRangeContaining(_hubFlowAnchorYmd);

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
                  switch ((forUncalledRate, scope)) {
                    (true, HubPeriod.day) => '미통화 비율',
                    (true, HubPeriod.week) => '주간 미통화 비율',
                    (true, HubPeriod.month) => '월간 미통화 비율',
                    (false, HubPeriod.day) => '초기응답 평균시간',
                    (false, HubPeriod.week) => '주간 초기응답 평균시간',
                    (false, HubPeriod.month) => '월간 초기응답 평균시간',
                  },
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (scope) {
                    HubPeriod.day => '${_hubFlowAnchorYmd} 기준',
                    HubPeriod.week =>
                      '${formatWeekRangeFlowLabel(weekRq.$1, weekRq.$2)} 주간 기준',
                    HubPeriod.month =>
                      '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} 기준',
                  },
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
    switch (scope) {
      case HubPeriod.day:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: forUncalledRate
                  ? ListQueryMode.incomplete
                  : ListQueryMode.today,
              date: _hubFlowAnchorYmd,
              initialAssignee: selected,
            ),
          ),
        );
      case HubPeriod.week:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: forUncalledRate
                  ? ListQueryMode.incomplete
                  : ListQueryMode.dateRange,
              date: weekRq.$1,
              dateEndInclusive: weekRq.$2,
              initialAssignee: selected,
            ),
          ),
        );
      case HubPeriod.month:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: forUncalledRate
                  ? ListQueryMode.incomplete
                  : ListQueryMode.dateRange,
              date: monthRq.$1,
              dateEndInclusive: monthRq.$2,
              initialAssignee: selected,
            ),
          ),
        );
    }
  }


  @override
  void initState() {
    super.initState();
    _hubFlowAnchorYmd = todayYmdSeoul();
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
    final d = _dayKey;
    final w = _weekKey;
    final m = _monthKey;
    for (final k in [d, w, m]) {
      ref.invalidate(hubPeriodStatsProvider(k));
      ref.invalidate(hubPeriodFollowOverviewProvider(k));
      ref.invalidate(hubPeriodQualityOverviewProvider(k));
    }
    ref.invalidate(todayStatsProvider);
    ref.invalidate(todayFollowOverviewProvider);
    ref.invalidate(todayCallQualityOverviewProvider);
    await Future.wait([
      ref.read(hubPeriodStatsProvider(d).future),
      ref.read(hubPeriodFollowOverviewProvider(d).future),
      ref.read(hubPeriodQualityOverviewProvider(d).future),
      ref.read(hubPeriodStatsProvider(w).future),
      ref.read(hubPeriodFollowOverviewProvider(w).future),
      ref.read(hubPeriodQualityOverviewProvider(w).future),
      ref.read(hubPeriodStatsProvider(m).future),
      ref.read(hubPeriodFollowOverviewProvider(m).future),
      ref.read(hubPeriodQualityOverviewProvider(m).future),
    ]);
  }

  void _openReceptionList(AppUser? user, HubPeriod scope) {
    final loginAssignee = user?.name.trim();
    final ia = (loginAssignee == null || loginAssignee.isEmpty)
        ? null
        : loginAssignee;
    switch (scope) {
      case HubPeriod.day:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.today,
              date: _hubFlowAnchorYmd,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.week:
        final r = seoulWeekRangeContaining(_hubFlowAnchorYmd);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.dateRange,
              date: r.$1,
              dateEndInclusive: r.$2,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.month:
        final r = seoulMonthRangeContaining(_hubFlowAnchorYmd);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.dateRange,
              date: r.$1,
              dateEndInclusive: r.$2,
              initialAssignee: ia,
            ),
          ),
        );
    }
  }

  Widget _buildPeriodFlowBlock({
    required AppUser? user,
    required ColorScheme scheme,
    required String title,
    required String subtitle,
    required HubPeriodKey periodKey,
    required String receptionLabel,
    required String incompleteLabel,
    required String followLabel,
  }) {
    final statsAsync = ref.watch(hubPeriodStatsProvider(periodKey));
    final followOverviewAsync =
        ref.watch(hubPeriodFollowOverviewProvider(periodKey));
    final qualityAsync =
        ref.watch(hubPeriodQualityOverviewProvider(periodKey));
    final scope = periodKey.period;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        statsAsync.when(
          data: (s) {
            final followCount = followOverviewAsync.valueOrNull?.total ?? 0;
            final quality = qualityAsync.valueOrNull;
            return _MiniStatsWidget(
              receptionLabel: receptionLabel,
              incompleteLabel: incompleteLabel,
              followLabel: followLabel,
              today: s.todayCount ?? 0,
              incomplete: s.incompleteCount ?? 0,
              todayFollow: followCount,
              uncalledRateText: quality == null
                  ? '-'
                  : '${(quality.uncalledRate * 100).toStringAsFixed(1)}%',
              avgFirstResponseText: quality == null
                  ? '-'
                  : _formatMinutes(quality.avgFirstResponseMinutes),
              onTapToday: () => _openReceptionList(user, scope),
              onTapIncomplete: () => _openIncompletePicker(scope),
              onTapTodayFollow: () => _openFollowPicker(scope),
              onTapUncalledRate: () => _openQualityPicker(
                    forUncalledRate: true,
                    scope: scope,
                  ),
              onTapFirstResponse: () => _openQualityPicker(
                    forUncalledRate: false,
                    scope: scope,
                  ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeHubFlowResetTickProvider, (previous, _) {
      if (!mounted) return;
      setState(() {
        _hubNavStep = HubNavStep.day;
        _hubFlowAnchorYmd = todayYmdSeoul();
      });
    });

    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final wk = seoulWeekRangeContaining(_hubFlowAnchorYmd);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
        // ─── 상단 배경 헤더 + 오늘 날짜 ───
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
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
            alignment: Alignment.center,
            child: Text(
              formatTodayGreetingSentenceKo(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
                height: 1.35,
                letterSpacing: -0.2,
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
                // ─── 미니 대시보드 (현황 요약) ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '업무 흐름',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    _buildHubFlowResetButton(scheme),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHubFlowDateBar(scheme),
                const SizedBox(height: 18),
                switch (_hubNavStep) {
                  HubNavStep.day => _buildPeriodFlowBlock(
                      user: user,
                      scheme: scheme,
                      title: '오늘의 흐름',
                      subtitle: formatYmdFlowLabelKo(_hubFlowAnchorYmd),
                      periodKey: _dayKey,
                      receptionLabel: '금일 접수',
                      incompleteLabel: '금일 미통화',
                      followLabel: '오늘 팔로우',
                    ),
                  HubNavStep.week => _buildPeriodFlowBlock(
                      user: user,
                      scheme: scheme,
                      title: '금주 흐름',
                      subtitle:
                          '${formatWeekRangeFlowLabel(wk.$1, wk.$2)} · 월~일 합산',
                      periodKey: _weekKey,
                      receptionLabel: '금주 접수',
                      incompleteLabel: '금주 미통화',
                      followLabel: '금주 팔로우',
                    ),
                  HubNavStep.month => _buildPeriodFlowBlock(
                      user: user,
                      scheme: scheme,
                      title: '금월 흐름',
                      subtitle:
                          '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} · 월 합산',
                      periodKey: _monthKey,
                      receptionLabel: '금월 접수',
                      incompleteLabel: '금월 미통화',
                      followLabel: '금월 팔로우',
                    ),
                },
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _MiniStatsWidget extends StatelessWidget {
  const _MiniStatsWidget({
    required this.receptionLabel,
    required this.incompleteLabel,
    required this.followLabel,
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

  final String receptionLabel;
  final String incompleteLabel;
  final String followLabel;
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTapToday,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _StatItem(
                        label: receptionLabel,
                        value: today.toString(),
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTapIncomplete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _StatItem(
                        label: incompleteLabel,
                        value: incomplete.toString(),
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: scheme.primary.withValues(alpha: 0.12),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTapTodayFollow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _StatItem(
                        label: followLabel,
                        value: todayFollow.toString(),
                        color: scheme.tertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.3,
                ),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: Color.alphaBlend(
              color.withValues(alpha: 0.88),
              scheme.surfaceContainerLowest,
            ),
          ),
        ),
      ],
    );
  }
}

