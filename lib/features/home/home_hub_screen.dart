import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/home/home_hub_visual.dart';
import 'package:coad_customer_calls/features/home/home_flow_stats.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/home/home_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_day_follow_pager_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class HomeHubScreen extends ConsumerStatefulWidget {
  const HomeHubScreen({super.key});

  @override
  ConsumerState<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends ConsumerState<HomeHubScreen> {
  static const String _longPressHintHiddenPrefKey =
      'home_flow_longpress_hint_hidden_v1';
  static const List<HomeHubSection> _sectionOrder = [
    HomeHubSection.flow,
    HomeHubSection.calendar,
  ];

  late PageController _sectionPageController;
  late String _hubFlowAnchorYmd;
  HubNavStep _hubNavStep = HubNavStep.day;
  HomeHubSection _section = HomeHubSection.flow;
  final Set<HomeHubSection> _materializedSections = {HomeHubSection.flow};
  CalendarFormat _launchCalendarFormat = CalendarFormat.week;
  int _calendarKeyNonce = 0;
  bool _showLongPressHint = true;
  bool _flowNoUncalledPopupEnabled = true;
  ProviderSubscription<HubNavStep>? _hubNavStepSub;
  ProviderSubscription<String>? _hubAnchorSub;
  ProviderSubscription<dynamic>? _pendingLaunchSub;
  ProviderSubscription<int>? _homeFlowResetSub;

  HubPeriodKey get _dayKey =>
      (period: HubPeriod.day, anchorYmd: _hubFlowAnchorYmd);

  HubPeriodKey get _weekKey =>
      (period: HubPeriod.week, anchorYmd: _hubFlowAnchorYmd);

  HubPeriodKey get _monthKey =>
      (period: HubPeriod.month, anchorYmd: _hubFlowAnchorYmd);

  HubPeriodKey get _previousPeriodKey => switch (_hubNavStep) {
    HubNavStep.day => (
      period: HubPeriod.day,
      anchorYmd: addDaysToYmd(_hubFlowAnchorYmd, -1),
    ),
    HubNavStep.week => (
      period: HubPeriod.week,
      anchorYmd: addDaysToYmd(
        seoulWeekRangeContaining(_hubFlowAnchorYmd).$1,
        -7,
      ),
    ),
    HubNavStep.month => (
      period: HubPeriod.month,
      anchorYmd: addCalendarMonthsFirstOfMonth(
        firstDayOfMonthYmd(_hubFlowAnchorYmd),
        -1,
      ),
    ),
  };

  String _comparePeriodLabel() => switch (_hubNavStep) {
    HubNavStep.day => '전일 대비',
    HubNavStep.week => '전주 대비',
    HubNavStep.month => '전월 대비',
  };

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
    _publishHubPeriod();
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

  String _hubJumpPeriodLabel() => switch (_hubNavStep) {
    HubNavStep.day => '금일',
    HubNavStep.week => '금주',
    HubNavStep.month => '금월',
  };

  IconData _hubJumpPeriodIcon() => switch (_hubNavStep) {
    HubNavStep.day => Icons.today_rounded,
    HubNavStep.week => Icons.view_week_rounded,
    HubNavStep.month => Icons.calendar_view_month_rounded,
  };

  String _hubJumpPeriodTooltip() => switch (_hubNavStep) {
    HubNavStep.day => '조회 기준을 오늘(금일)로 이동',
    HubNavStep.week => '조회 기준을 이번 주(금주)로 이동',
    HubNavStep.month => '조회 기준을 이번 달(금월)로 이동',
  };

  void _selectHubNavStep(HubNavStep next) {
    setState(() {
      _hubNavStep = next;
      final today = todayYmdSeoul();
      _hubFlowAnchorYmd = switch (next) {
        HubNavStep.day => today,
        HubNavStep.week => seoulWeekRangeContaining(today).$1,
        HubNavStep.month => firstDayOfMonthYmd(today),
      };
    });
    _publishHubPeriod();
  }

  void _shiftHubNav(int dir) {
    final today = todayYmdSeoul();
    switch (_hubNavStep) {
      case HubNavStep.day:
        final next = addDaysToYmd(_hubFlowAnchorYmd, dir);
        if (next.compareTo(today) > 0) return;
        setState(() => _hubFlowAnchorYmd = next);
        _publishHubPeriod();
        return;
      case HubNavStep.week:
        final mon = seoulWeekRangeContaining(_hubFlowAnchorYmd).$1;
        final nextMon = addDaysToYmd(mon, 7 * dir);
        if (nextMon.compareTo(today) > 0) return;
        setState(() => _hubFlowAnchorYmd = nextMon);
        _publishHubPeriod();
        return;
      case HubNavStep.month:
        final curFirst = firstDayOfMonthYmd(_hubFlowAnchorYmd);
        final nextFirst = addCalendarMonthsFirstOfMonth(curFirst, dir);
        if (nextFirst.compareTo(firstDayOfMonthYmd(today)) > 0) return;
        setState(() => _hubFlowAnchorYmd = nextFirst);
        _publishHubPeriod();
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

  /// 좌우 이동 시 바뀌는 **조회 기간** (금일/금주/금월 흐름 제목 아래에만 표시).
  String _hubFlowNavigatedPeriodLabel() {
    switch (_hubNavStep) {
      case HubNavStep.day:
        final date = formatYmdFlowLabelKo(_hubFlowAnchorYmd);
        if (_hubFlowAnchorYmd == todayYmdSeoul()) {
          return '$date · 오늘';
        }
        return date;
      case HubNavStep.week:
        final w = seoulWeekRangeContaining(_hubFlowAnchorYmd);
        return formatWeekRangeFlowLabel(w.$1, w.$2);
      case HubNavStep.month:
        return formatYearMonthLabelKo(_hubFlowAnchorYmd);
    }
  }

  /// 업데이트 안내는 메인 AppBar 칩 단일 진입점 — 홈 헤더에는 표시하지 않음.
  /// 헤더는 세그먼트 + (흐름일 때만) 기간 한 줄로 밀도 최소화.
  Widget _buildUnifiedHomeTop(ColorScheme scheme, AppUser? user) {
    final compact = _section != HomeHubSection.flow;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, compact ? 6 : 8, 12, compact ? 8 : 10),
      decoration: HomeHubVisual.header(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer(
            builder: (context, ref, _) => _buildSectionSegmentBar(
              scheme,
              embedded: true,
              pendingBadge: ref
                  .watch(hubSegmentIncompleteBadgeProvider)
                  .valueOrNull,
              calendarBadge: ref
                  .watch(hubSegmentCalendarBadgeProvider)
                  .valueOrNull,
            ),
          ),
          if (_section == HomeHubSection.flow) ...[
            const SizedBox(height: 8),
            _buildCompactFlowControls(scheme),
          ],
        ],
      ),
    );
  }

  /// 금일/금주/금월 · 기간 이동 · 오늘로 를 한 블록에 배치.
  Widget _buildCompactFlowControls(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniPeriodChip(
                  scheme: scheme,
                  step: HubNavStep.day,
                  label: '일',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMiniPeriodChip(
                  scheme: scheme,
                  step: HubNavStep.week,
                  label: '주',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMiniPeriodChip(
                  scheme: scheme,
                  step: HubNavStep.month,
                  label: '월',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftHubNav(-1),
                tooltip: '이전 기간',
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(32, 30),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Expanded(
                child: Text(
                  _hubFlowNavigatedPeriodLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimary,
                    height: 1.1,
                  ),
                ),
              ),
              IconButton(
                onPressed: _canShiftHubNavNewer()
                    ? () => _shiftHubNav(1)
                    : null,
                tooltip: '다음 기간',
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onPrimary,
                  disabledForegroundColor: scheme.onPrimary.withValues(
                    alpha: 0.35,
                  ),
                  minimumSize: const Size(32, 30),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 3),
              _buildTodayJumpButton(scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPeriodChip({
    required ColorScheme scheme,
    required HubNavStep step,
    required String label,
  }) {
    final selected = _hubNavStep == step;
    return Material(
      color: selected
          ? scheme.surface
          : scheme.onPrimary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _selectHubNavStep(step),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              color: selected ? scheme.primary : scheme.onPrimary,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayJumpButton(ColorScheme scheme) {
    final enabled = !_isHubFlowOnCurrentPeriod();
    final borderColor = enabled
        ? scheme.surface.withValues(alpha: 0.9)
        : scheme.onPrimary.withValues(alpha: 0.25);
    final bgColor = enabled
        ? scheme.surface
        : scheme.onPrimary.withValues(alpha: 0.1);
    final fgColor = enabled
        ? scheme.primary
        : scheme.onPrimary.withValues(alpha: 0.45);
    return Tooltip(
      message: enabled ? _hubJumpPeriodTooltip() : '이미 현재 기준',
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? _resetHubFlowAnchorToCurrent : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: enabled ? 1.5 : 1),
            ),
            child: Icon(Icons.my_location_rounded, size: 16, color: fgColor),
          ),
        ),
      ),
    );
  }

  Widget _buildHubPeriodToggleChip({
    required ColorScheme scheme,
    required HubNavStep step,
    required String label,
    required IconData icon,
  }) {
    final selected = _hubNavStep == step;
    final fg = selected
        ? scheme.primary
        : scheme.onPrimary.withValues(alpha: 0.88);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? scheme.surface
              : scheme.onPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _selectHubNavStep(step),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? scheme.surface
                      : scheme.onPrimary.withValues(alpha: 0.35),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: fg),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: fg,
                        height: 1,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildEmbeddedFlowDateControls(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftHubNav(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 24),
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
                tooltip: switch (_hubNavStep) {
                  HubNavStep.day => '이전 날',
                  HubNavStep.week => '이전 주',
                  HubNavStep.month => '이전 달',
                },
              ),
              const SizedBox(width: 4),
              _buildHubPeriodToggleChip(
                scheme: scheme,
                step: HubNavStep.day,
                label: '금일',
                icon: Icons.today_rounded,
              ),
              const SizedBox(width: 5),
              _buildHubPeriodToggleChip(
                scheme: scheme,
                step: HubNavStep.week,
                label: '금주',
                icon: Icons.view_week_rounded,
              ),
              const SizedBox(width: 5),
              _buildHubPeriodToggleChip(
                scheme: scheme,
                step: HubNavStep.month,
                label: '금월',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _canShiftHubNavNewer()
                    ? () => _shiftHubNav(1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 24),
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onPrimary,
                  disabledForegroundColor: scheme.onPrimary.withValues(
                    alpha: 0.35,
                  ),
                  minimumSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
                tooltip: switch (_hubNavStep) {
                  HubNavStep.day => '다음 날',
                  HubNavStep.week => '다음 주',
                  HubNavStep.month => '다음 달',
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _hubFlowNavigatedPeriodLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildHubFlowJumpChip(scheme, onPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHubFlowJumpChip(
    ColorScheme scheme, {
    required bool onPrimary,
    bool compact = false,
  }) {
    final enabled = !_isHubFlowOnCurrentPeriod();
    final label = _hubJumpPeriodLabel();
    final icon = _hubJumpPeriodIcon();
    final tip = _hubJumpPeriodTooltip();

    final fg = onPrimary
        ? (enabled ? scheme.primary : scheme.onPrimary.withValues(alpha: 0.4))
        : (enabled
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant.withValues(alpha: 0.45));
    final bg = onPrimary
        ? (enabled ? scheme.surface : scheme.onPrimary.withValues(alpha: 0.1))
        : (enabled
              ? scheme.secondaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5));
    final border = onPrimary
        ? (enabled ? scheme.surface : scheme.onPrimary.withValues(alpha: 0.25))
        : scheme.outlineVariant.withValues(alpha: 0.35);

    return Tooltip(
      message: enabled ? tip : '현재 $label 기준으로 보는 중',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        elevation: enabled && onPrimary ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          onTap: enabled ? _resetHubFlowAnchorToCurrent : null,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 27 : 0),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 10,
              vertical: compact ? 7 : 7,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
              border: Border.all(color: border, width: enabled ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 14 : 16, color: fg),
                SizedBox(width: compact ? 3 : 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 12,
                    fontWeight: FontWeight.w900,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
                if (enabled) ...[
                  SizedBox(width: compact ? 1 : 2),
                  Icon(
                    Icons.north_west_rounded,
                    size: compact ? 12 : 14,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ),
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

  String _callAssigneeOf(dynamic row) {
    final a = (row.assignedTo ?? '').toString().trim();
    return a.isEmpty ? '미지정' : a;
  }

  String _regionAssigneeOf(dynamic row) {
    final manager = (row.assignedTo ?? '').toString().trim();
    if (manager.isNotEmpty) return manager;
    return '미지정';
  }

  Map<String, int> _countsFromRows(
    List<dynamic> rows,
    String Function(dynamic) assigneeOf,
  ) {
    final counts = <String, int>{'전체': rows.length};
    for (final row in rows) {
      final assignee = assigneeOf(row);
      counts[assignee] = (counts[assignee] ?? 0) + 1;
    }
    return counts;
  }

  String _loginDefaultAssignee(Map<String, int> counts) {
    final loginName = ref.read(authControllerProvider)?.name.trim();
    if (loginName != null &&
        loginName.isNotEmpty &&
        counts.containsKey(loginName)) {
      return loginName;
    }
    return '전체';
  }

  List<String> _sortedAssigneeKeys(
    Map<String, int> counts,
    String defaultAssignee,
  ) {
    return counts.keys.toList()..sort((a, b) {
      if (a == '전체') return -1;
      if (b == '전체') return 1;
      if (a == defaultAssignee) return -1;
      if (b == defaultAssignee) return 1;
      final countA = counts[a] ?? 0;
      final countB = counts[b] ?? 0;
      if (countA != countB) return countB.compareTo(countA);
      return a.compareTo(b);
    });
  }

  String? _listInitialAssignee(String assignee) =>
      assignee == '전체' ? null : assignee;

  String _hubPeriodScopeLabel(HubPeriod scope, {bool follow = false}) {
    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    return switch (scope) {
      HubPeriod.day => '${_hubFlowAnchorYmd} 기준',
      HubPeriod.week => '${formatWeekRangeFlowLabel(weekR.$1, weekR.$2)} 주간 기준',
      HubPeriod.month =>
        follow
            ? '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} 팔로우 기준'
            : '${formatYearMonthLabelKo(_hubFlowAnchorYmd)} 기준',
    };
  }

  Future<String?> _pickHubAssignee({
    required String title,
    required String subtitle,
    required Map<String, int> counts,
    int? truncationWarnAbove,
    bool forcePicker = false,
  }) async {
    final defaultAssignee = _loginDefaultAssignee(counts);
    if (!forcePicker && defaultAssignee != '전체') {
      return defaultAssignee;
    }

    final assignees = _sortedAssigneeKeys(counts, defaultAssignee);
    final isTruncated =
        truncationWarnAbove != null &&
        (counts['전체'] ?? 0) >= truncationWarnAbove;

    return showModalBottomSheet<String>(
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
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (isTruncated) ...[
                  const SizedBox(height: 4),
                  Text(
                    '상위 $truncationWarnAbove건 기준으로 집계됩니다.',
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
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
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

  Future<void> _pushReceptionList(HubPeriod scope, String assignee) async {
    final ia = _listInitialAssignee(assignee);
    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthR = seoulMonthRangeContaining(_hubFlowAnchorYmd);
    switch (scope) {
      case HubPeriod.day:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.today,
              date: _hubFlowAnchorYmd,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.week:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.dateRange,
              date: weekR.$1,
              dateEndInclusive: weekR.$2,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.month:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.dateRange,
              date: monthR.$1,
              dateEndInclusive: monthR.$2,
              initialAssignee: ia,
            ),
          ),
        );
    }
  }

  Future<void> _openPendingUncalledPicker({bool forcePicker = false}) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    List<SalesCall> rows;
    try {
      rows =
          await _withFreshDataLoading(() async {
            ref.invalidate(hubPendingUncalledCallsProvider);
            return ref.read(hubPendingUncalledCallsProvider.future);
          }) ??
          const [];
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('처리할 미통화 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final overrides = await ref.read(tempManagerOverridesProvider.future);
    final counts = _countsFromRows(
      rows,
      (row) => displayAssigneeForCall(row, overrides, DateTime.now()),
    );
    if (!forcePicker && rows.isEmpty) {
      await _showAutoCloseInfoDialog('처리할 미통화가 없습니다.');
      return;
    }
    final selected = await _pickHubAssignee(
      title: '처리할 미통화',
      subtitle: '최근 $pendingUncalledLookbackDays일',
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushPendingUncalledList(selected);
  }

  Future<void> _pushPendingUncalledList(String assignee) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.pendingUncalled,
          date: pendingUncalledFromYmd(_hubFlowAnchorYmd),
          initialAssignee: assignee,
        ),
      ),
    );
  }

  Future<void> _pushIncompleteListForDate(
    String anchorYmd,
    String assignee,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incomplete,
          date: anchorYmd,
          initialAssignee: assignee,
        ),
      ),
    );
  }

  Future<void> _pushIncompleteList(HubPeriod scope, String assignee) async {
    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthR = seoulMonthRangeContaining(_hubFlowAnchorYmd);
    switch (scope) {
      case HubPeriod.day:
        await _pushIncompleteListForDate(_hubFlowAnchorYmd, assignee);
      case HubPeriod.week:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.incomplete,
              date: weekR.$1,
              dateEndInclusive: weekR.$2,
              initialAssignee: assignee,
            ),
          ),
        );
      case HubPeriod.month:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.incomplete,
              date: monthR.$1,
              dateEndInclusive: monthR.$2,
              initialAssignee: assignee,
            ),
          ),
        );
    }
  }

  Future<void> _pushFollowList(HubPeriod scope, String assignee) async {
    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthR = seoulMonthRangeContaining(_hubFlowAnchorYmd);
    switch (scope) {
      case HubPeriod.day:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallDayFollowPagerScreen(
              initialDateYmd: _hubFlowAnchorYmd,
              initialAssignee: assignee,
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
              initialAssignee: assignee,
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
              initialAssignee: assignee,
            ),
          ),
        );
    }
  }

  Future<void> _openReceptionPicker(
    HubPeriod scope, {
    bool forcePicker = false,
  }) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    // 흐름 카드가 이미 조회한 bundle 재사용 — 추가 API 호출 없음.
    final key = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    List<SalesCall> rows;
    try {
      final bundle = await ref.read(
        hubPeriodReceptionBundleProvider(key).future,
      );
      rows = bundle.calls;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('접수 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    final counts = _countsFromRows(rows, _callAssigneeOf);
    final selected = await _pickHubAssignee(
      title: '접수 담당자 선택',
      subtitle: _hubPeriodScopeLabel(scope),
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushReceptionList(scope, selected);
  }

  Future<void> _openFollowPicker(
    HubPeriod scope, {
    bool forcePicker = false,
  }) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    // 팔로우 snapshot(미완료만) 재사용 — 추가 API 호출 없음.
    final key = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    List<SalesCall> rows;
    try {
      final snapshot = await ref.read(
        hubPeriodFollowSnapshotProvider(key).future,
      );
      rows = snapshot.remainingCalls;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팔로우 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    final counts = _countsFromRows(rows, _regionAssigneeOf);
    final selected = await _pickHubAssignee(
      title: '날짜 팔로우 담당자 선택',
      subtitle: _hubPeriodScopeLabel(scope, follow: true),
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushFollowList(scope, selected);
  }

  Future<void> _openUpdatedPicker(
    HubPeriod scope, {
    bool forcePicker = false,
  }) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    final key = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    List<SalesCall> rows;
    try {
      rows = await ref.read(hubPeriodUpdatedCallsProvider(key).future);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('업데이트 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final counts = _countsFromRows(rows, _callAssigneeOf);
    if (!forcePicker && rows.isEmpty) {
      await _showAutoCloseInfoDialog('업데이트가 없습니다.');
      return;
    }
    final selected = await _pickHubAssignee(
      title: '업데이트 담당자 선택',
      subtitle: _hubPeriodScopeLabel(scope),
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushUpdatedList(scope, selected);
  }

  Future<void> _pushUpdatedList(HubPeriod scope, String assignee) async {
    final ia = _listInitialAssignee(assignee);
    final weekR = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    final monthR = seoulMonthRangeContaining(_hubFlowAnchorYmd);
    switch (scope) {
      case HubPeriod.day:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.updatedRange,
              date: _hubFlowAnchorYmd,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.week:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.updatedRange,
              date: weekR.$1,
              dateEndInclusive: weekR.$2,
              initialAssignee: ia,
            ),
          ),
        );
      case HubPeriod.month:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SalesCallListScreen(
              mode: ListQueryMode.updatedRange,
              date: monthR.$1,
              dateEndInclusive: monthR.$2,
              initialAssignee: ia,
            ),
          ),
        );
    }
  }

  Future<T?> _withFreshDataLoading<T>(Future<T> Function() load) async {
    if (!mounted) return null;
    final navigator = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      '미통화 최신 확인 중…',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    try {
      return await load();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<void> _openIncompletePicker(
    HubPeriod scope, {
    bool forcePicker = false,
  }) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    final periodKey = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    List<SalesCall> rows;
    try {
      final bundle = await _withFreshDataLoading(
        () => refreshHubPeriodUncalledBundle(ref, periodKey),
      );
      if (bundle == null || !mounted) return;
      rows = bundle.uncalledCalls;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미통화 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }

    if (!mounted) return;

    final overrides = await ref.read(tempManagerOverridesProvider.future);
    final counts = _countsFromRows(
      rows,
      (row) => displayAssigneeForCall(row, overrides, DateTime.now()),
    );
    if (!forcePicker && _flowNoUncalledPopupEnabled && rows.isEmpty) {
      await _showAutoCloseInfoDialog('미통화가 없습니다.');
      return;
    }
    final selected = await _pickHubAssignee(
      title: '미통화 담당자 선택',
      subtitle: _hubPeriodScopeLabel(scope),
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushIncompleteList(scope, selected);
  }

  Future<void> _openPreviousDayIncompletePicker({
    bool forcePicker = false,
  }) async {
    if (forcePicker && _showLongPressHint) {
      _dismissLongPressHint();
    }
    final periodKey = _previousPeriodKey;
    if (periodKey.period != HubPeriod.day) return;

    List<SalesCall> rows;
    try {
      final bundle = await _withFreshDataLoading(
        () => refreshHubPeriodUncalledBundle(ref, periodKey),
      );
      if (bundle == null || !mounted) return;
      rows = bundle.uncalledCalls;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전일 미통화 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final overrides = await ref.read(tempManagerOverridesProvider.future);
    final counts = _countsFromRows(
      rows,
      (row) => displayAssigneeForCall(row, overrides, DateTime.now()),
    );
    if (!forcePicker && rows.isEmpty) {
      await _showAutoCloseInfoDialog('전일 미통화가 없습니다.');
      return;
    }
    final selected = await _pickHubAssignee(
      title: '전일 미통화',
      subtitle: '${formatYmdFlowLabelKo(periodKey.anchorYmd)} 접수',
      counts: counts,
      forcePicker: forcePicker,
    );
    if (!mounted || selected == null) return;
    await _pushIncompleteListForDate(periodKey.anchorYmd, selected);
  }

  Future<void> _showAutoCloseInfoDialog(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    Future.delayed(duration, () {
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityPickerLeading({
    required ColorScheme scheme,
    required String assignee,
    required int rankIndex,
    required bool forUncalledRate,
  }) {
    if (!forUncalledRate && rankIndex >= 0 && rankIndex < 3) {
      final medals = [
        (label: '1', bg: Colors.amber.shade700, fg: Colors.white),
        (label: '2', bg: Colors.blueGrey.shade500, fg: Colors.white),
        (label: '3', bg: Colors.brown.shade500, fg: Colors.white),
      ];
      final medal = medals[rankIndex];
      return CircleAvatar(
        radius: 16,
        backgroundColor: medal.bg,
        child: Text(
          medal.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: medal.fg,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Icon(
        assignee == '전체' ? Icons.people_alt_rounded : Icons.person_rounded,
        size: 18,
        color: scheme.primary,
      ),
    );
  }

  Future<void> _openQualityPicker({
    required bool forUncalledRate,
    required HubPeriod scope,
  }) async {
    final periodKey = (period: scope, anchorYmd: _hubFlowAnchorYmd);
    CallQualityOverview overview;
    try {
      overview = await ref.read(
        hubPeriodQualityOverviewProvider(periodKey).future,
      );
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

    int compareFirstResponseLongest(String a, String b) {
      final ma = metricMap[a]?.avgFirstResponseMinutes;
      final mb = metricMap[b]?.avgFirstResponseMinutes;
      if (ma == null && mb == null) return a.compareTo(b);
      if (ma == null) return 1;
      if (mb == null) return -1;
      final cmp = mb.compareTo(ma);
      if (cmp != 0) return cmp;
      return a.compareTo(b);
    }

    final rankedIndividuals =
        metricMap.keys.where((name) => name != '전체').toList()..sort(
          forUncalledRate
              ? (a, b) {
                  final totalA = metricMap[a]?.total ?? 0;
                  final totalB = metricMap[b]?.total ?? 0;
                  if (totalA != totalB) return totalB.compareTo(totalA);
                  return a.compareTo(b);
                }
              : compareFirstResponseLongest,
        );

    final assignees = ['전체', ...rankedIndividuals];

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
                    (false, HubPeriod.day) => '첫 응답 평균 (담당자별)',
                    (false, HubPeriod.week) => '주간 첫 응답 (담당자별)',
                    (false, HubPeriod.month) => '월간 첫 응답 (담당자별)',
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
                if (!forUncalledRate) ...[
                  const SizedBox(height: 4),
                  Text(
                    '첫 응답이 긴 순 · 1·2·3등 표시',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
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
                      final rankIndex = !forUncalledRate && assignee != '전체'
                          ? rankedIndividuals.indexOf(assignee)
                          : -1;
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(assignee),
                        leading: _buildQualityPickerLeading(
                          scheme: scheme,
                          assignee: assignee,
                          rankIndex: rankIndex,
                          forUncalledRate: forUncalledRate,
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
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
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

  int _sectionIndex(HomeHubSection section) =>
      _sectionOrder.indexOf(section).clamp(0, _sectionOrder.length - 1);

  HomeHubSection _sectionAt(int index) =>
      _sectionOrder[index.clamp(0, _sectionOrder.length - 1)];

  void _jumpSectionPage(int index) {
    if (!_sectionPageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sectionPageController.hasClients) {
          _sectionPageController.jumpToPage(index);
        }
      });
      return;
    }
    _sectionPageController.jumpToPage(index);
  }

  void _goToSection(HomeHubSection section, {bool fromPill = false}) {
    _materializeSection(section);
    if (_section == section && !fromPill) return;
    HapticFeedback.selectionClick();
    setState(() => _section = section);
    if (_sectionPageController.hasClients) {
      _sectionPageController.animateToPage(
        _sectionIndex(section),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSectionPageChanged(int index) {
    final next = _sectionAt(index);
    _materializeSection(next);
    if (_section == next) return;
    HapticFeedback.selectionClick();
    setState(() => _section = next);
  }

  void _consumePendingLaunch() {
    final next = ref.read(pendingConsultationLaunchProvider);
    if (next == null || !mounted) return;
    _materializeSection(next.section);
    setState(() {
      _section = next.section;
      _launchCalendarFormat = next.calendarFormat;
      if (next.section == HomeHubSection.calendar) {
        _calendarKeyNonce++;
      }
    });
    _jumpSectionPage(_sectionIndex(next.section));
    ref.read(pendingConsultationLaunchProvider.notifier).state = null;
  }

  Future<void> _checkAndSyncPending() async {
    final result = await refreshPendingSyncCount(ref, autoSync: true);
    if (!mounted) return;
    if (result.synced > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('미전송 ${result.synced}건이 동기화되었습니다.')),
      );
    }
  }

  void _publishHubPeriod() {
    ref.read(homeHubNavStepProvider.notifier).state = _hubNavStep;
    ref.read(homeHubFlowAnchorYmdProvider.notifier).state = _hubFlowAnchorYmd;
    prefetchHubPeriodFlow(
      ref,
      _activeFlowPeriodKey,
      previousKey: _previousPeriodKey,
    );
  }

  void _materializeSection(HomeHubSection section) {
    if (_materializedSections.contains(section)) return;
    setState(() => _materializedSections.add(section));
  }

  Widget _lazySectionPage(HomeHubSection section, Widget child) {
    if (!_materializedSections.contains(section)) {
      return const SizedBox.expand();
    }
    return HomeKeepAliveSection(child: child);
  }

  Future<void> _loadHomeFlowPrefs() async {
    final prefs = ref.read(appDependenciesProvider).prefs;
    final hidden = prefs.getBool(_longPressHintHiddenPrefKey) ?? false;
    final noUncalledPopup = prefs.getBool(homeFlowUncalledPopupPrefKey) ?? true;
    if (!mounted) return;
    setState(() {
      _showLongPressHint = !hidden;
      _flowNoUncalledPopupEnabled = noUncalledPopup;
    });
  }

  Future<void> _dismissLongPressHint() async {
    if (!_showLongPressHint) return;
    setState(() => _showLongPressHint = false);
    final prefs = ref.read(appDependenciesProvider).prefs;
    await prefs.setBool(_longPressHintHiddenPrefKey, true);
  }

  @override
  void initState() {
    super.initState();
    _hubFlowAnchorYmd = todayYmdSeoul();
    _sectionPageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publishHubPeriod();
      _checkAndSyncPending();
      _consumePendingLaunch();
      _loadHomeFlowPrefs();
    });
    _homeFlowResetSub = ref.listenManual<int>(homeHubFlowResetTickProvider, (
      previous,
      next,
    ) {
      if (!mounted || previous == next) return;
      setState(() {
        _hubNavStep = HubNavStep.day;
        _hubFlowAnchorYmd = todayYmdSeoul();
        _section = HomeHubSection.flow;
      });
      _publishHubPeriod();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpSectionPage(0);
      });
    });
    _pendingLaunchSub = ref.listenManual(
      pendingConsultationLaunchProvider,
      (_, _) => _consumePendingLaunch(),
    );
    _hubNavStepSub = ref.listenManual(homeHubNavStepProvider, (prev, next) {
      if (_hubNavStep == next) return;
      setState(() => _hubNavStep = next);
    });
    _hubAnchorSub = ref.listenManual(homeHubFlowAnchorYmdProvider, (
      prev,
      next,
    ) {
      if (_hubFlowAnchorYmd == next) return;
      setState(() => _hubFlowAnchorYmd = next);
    });
  }

  @override
  void dispose() {
    _hubNavStepSub?.close();
    _hubAnchorSub?.close();
    _pendingLaunchSub?.close();
    _homeFlowResetSub?.close();
    _sectionPageController.dispose();
    super.dispose();
  }

  HubPeriodKey get _activeFlowPeriodKey => switch (_hubNavStep) {
    HubNavStep.day => _dayKey,
    HubNavStep.week => _weekKey,
    HubNavStep.month => _monthKey,
  };

  CalendarFollowRangeKey _calendarRangeKeyForHub() {
    if (_launchCalendarFormat == CalendarFormat.month) {
      final m = seoulMonthRangeContaining(_hubFlowAnchorYmd);
      return (startYmd: m.$1, endYmd: m.$2);
    }
    final w = seoulWeekRangeContaining(_hubFlowAnchorYmd);
    return (startYmd: w.$1, endYmd: w.$2);
  }

  Future<void> _refreshActiveFlowPeriod() async {
    // day 기간은 hubDayReceptionCallsProvider까지 무효화해야 카드 숫자가 갱신된다.
    // bundle만 invalidate하면 빈 day 캐시가 재사용되어 0으로 남을 수 있다.
    await refreshHubPeriodFlow(
      ref,
      _activeFlowPeriodKey,
      previousKey: _previousPeriodKey,
    );
  }

  void _invalidateSegmentBadges() {
    // 요약만 invalidate하면 상위(calls/overrides) 오류 캐시가 그대로 재사용된다.
    ref.invalidate(hubPendingUncalledCallsProvider);
    ref.invalidate(tempManagerOverridesProvider);
    ref.invalidate(hubPendingUncalledSummaryProvider);
  }

  Future<void> _onRefresh() async {
    _invalidateSegmentBadges();
    switch (_section) {
      case HomeHubSection.flow:
        await _refreshActiveFlowPeriod();
      case HomeHubSection.calendar:
        final calKey = _calendarRangeKeyForHub();
        ref.invalidate(calendarFollowRangeProvider(calKey));
        await ref.read(calendarFollowRangeProvider(calKey).future);
        if (mounted) {
          setState(() => _calendarKeyNonce++);
        }
    }
    await _checkAndSyncPending();
  }

  Widget _buildSectionSegmentBar(
    ColorScheme scheme, {
    bool embedded = false,
    int? pendingBadge,
    int? calendarBadge,
  }) {
    const sections = <(HomeHubSection, String, IconData)>[
      (HomeHubSection.flow, '흐름', Icons.insights_rounded),
      (HomeHubSection.calendar, '달력', Icons.calendar_month_rounded),
    ];

    int badgeCountFor(HomeHubSection section) => switch (section) {
      HomeHubSection.flow => pendingBadge ?? 0,
      HomeHubSection.calendar => calendarBadge ?? 0,
    };

    bool showsCountBadge(HomeHubSection section) =>
        section == HomeHubSection.flow || section == HomeHubSection.calendar;

    final trackColor = embedded
        ? scheme.onPrimary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);

    final bar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(11),
        border: embedded
            ? Border.all(color: scheme.onPrimary.withValues(alpha: 0.14))
            : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          for (final (section, label, icon) in sections)
            Builder(
              builder: (context) {
                final accent = HomeHubVisual.sectionTone(
                  section,
                  scheme,
                ).accent;
                final selectedBg = embedded
                    ? accent.withValues(alpha: 0.22)
                    : accent.withValues(alpha: 0.14);
                final selectedFg = embedded
                    ? scheme.onPrimary
                    : scheme.onSurface;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _goToSection(section, fromPill: true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      // 섹션별 고유 톤으로 선택 상태를 분리해 시인성을 높인다.
                      decoration: BoxDecoration(
                        color: _section == section
                            ? selectedBg
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        border: _section == section
                            ? Border.all(
                                color: accent.withValues(
                                  alpha: embedded ? 0.55 : 0.45,
                                ),
                              )
                            : null,
                        boxShadow: _section == section
                            ? [
                                BoxShadow(
                                  color: accent.withValues(
                                    alpha: embedded ? 0.24 : 0.16,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 15,
                            color: _section == section
                                ? selectedFg
                                : (embedded
                                      ? scheme.onPrimary.withValues(alpha: 0.9)
                                      : scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _section == section
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _section == section
                                    ? selectedFg
                                    : (embedded
                                          ? scheme.onPrimary.withValues(
                                              alpha: 0.92,
                                            )
                                          : scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                          if (showsCountBadge(section)) ...[
                            const SizedBox(width: 5),
                            _buildSectionCountBadge(
                              count: badgeCountFor(section),
                              accent: HomeHubVisual.sectionTone(
                                section,
                                scheme,
                              ).accent,
                              selected: _section == section,
                              onPrimary: embedded && _section != section,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );

    if (embedded) return bar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: bar,
    );
  }

  Widget _buildSectionCountBadge({
    required int count,
    required Color accent,
    required bool selected,
    required bool onPrimary,
  }) {
    final hasCount = count > 0;
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(
        horizontal: label.length >= 3 ? 4 : 5,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: hasCount
            ? accent.withValues(alpha: onPrimary ? 0.92 : 0.88)
            : (onPrimary
                  ? Colors.white.withValues(alpha: 0.16)
                  : accent.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: hasCount
              ? Colors.white
              : (onPrimary
                    ? Colors.white.withValues(alpha: 0.88)
                    : accent.withValues(alpha: 0.75)),
          height: 1.2,
        ),
      ),
    );
  }

  double _homeBottomInset(BuildContext context) => 12;

  Widget _buildFlowBody(ColorScheme scheme, AppUser? user) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 2, 12, 6 + _homeBottomInset(context)),
      child: _buildPeriodFlowBlock(
        user: user,
        scheme: scheme,
        periodKey: switch (_hubNavStep) {
          HubNavStep.day => _dayKey,
          HubNavStep.week => _weekKey,
          HubNavStep.month => _monthKey,
        },
        receptionLabel: switch (_hubNavStep) {
          HubNavStep.day => '금일 접수',
          HubNavStep.week => '금주 접수',
          HubNavStep.month => '금월 접수',
        },
        incompleteLabel: switch (_hubNavStep) {
          HubNavStep.day => '금일 미통화',
          HubNavStep.week => '금주 미통화',
          HubNavStep.month => '금월 미통화',
        },
        followLabel: switch (_hubNavStep) {
          HubNavStep.day => '오늘 팔로우',
          HubNavStep.week => '이번 주 팔로우',
          HubNavStep.month => '이번 달 팔로우',
        },
        updatedLabel: switch (_hubNavStep) {
          HubNavStep.day => '금일 업데이트',
          HubNavStep.week => '금주 업데이트',
          HubNavStep.month => '금월 업데이트',
        },
      ),
    );
  }

  Widget _buildCalendarBody() {
    return Padding(
      padding: EdgeInsets.only(bottom: _homeBottomInset(context)),
      child: HomeFollowCalendarPanel(
        key: ValueKey('cal_$_calendarKeyNonce'),
        initialCalendarFormat: _launchCalendarFormat,
        fitSingleScreen: true,
        onRefresh: _onRefresh,
      ),
    );
  }

  String _formatCountDelta(int current, int previous) {
    final d = current - previous;
    if (d == 0) return '±0';
    return d > 0 ? '+$d' : '$d';
  }

  Widget _buildPreviousDayUncalledBanner({
    required ColorScheme scheme,
    required int count,
    required String anchorYmd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.tertiaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openPreviousDayIncompletePicker(),
          onLongPress: () =>
              _openPreviousDayIncompletePicker(forcePicker: true),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: scheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '전일 미통화 $count',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        count > 0
                            ? '${formatYmdFlowLabelKo(anchorYmd)} 접수 · 늦은 문의 확인'
                            : '${formatYmdFlowLabelKo(anchorYmd)} 접수 · 미통화 없음',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onTertiaryContainer.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingUncalledBanner(ColorScheme scheme) {
    final summaryAsync = ref.watch(hubPendingUncalledSummaryProvider);
    return summaryAsync.when(
      data: (summary) {
        final loginName = ref.watch(authControllerProvider)?.name?.trim();
        final count = loginName != null && loginName.isNotEmpty
            ? summary.userCount
            : summary.total;
        if (count == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: scheme.errorContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _openPendingUncalledPicker(),
              onLongPress: () => _openPendingUncalledPicker(forcePicker: true),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '처리할 미통화 $count',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: scheme.onErrorContainer,
                            ),
                          ),
                          Text(
                            '오늘 ${summary.todayCount} · 이월 ${summary.carriedOverCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.onErrorContainer.withValues(
                                alpha: 0.82,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onErrorContainer.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LinearProgressIndicator(
          minHeight: 3,
          color: scheme.error.withValues(alpha: 0.5),
          backgroundColor: scheme.errorContainer.withValues(alpha: 0.2),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: scheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _invalidateSegmentBadges,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '처리할 미통화를 불러오지 못했습니다 · 탭하여 다시 시도\n'
                      '${koreanErrorMessage(error)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowReceptionCompareBanner({
    required ColorScheme scheme,
    required String compareLabel,
    required int reception,
    required int prevReception,
  }) {
    final delta = reception - prevReception;
    final deltaText = _formatCountDelta(reception, prevReception);
    final deltaColor = delta == 0
        ? scheme.onSurfaceVariant
        : delta > 0
        ? scheme.tertiary
        : scheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$compareLabel 접수 ',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: deltaText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: deltaColor,
              ),
            ),
            TextSpan(
              text: ' (현재 $reception건 / 이전 $prevReception건)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPeriodFlowBlock({
    required AppUser? user,
    required ColorScheme scheme,
    required HubPeriodKey periodKey,
    required String receptionLabel,
    required String incompleteLabel,
    required String followLabel,
    required String updatedLabel,
  }) {
    final statsAsync = ref.watch(hubPeriodStatsProvider(periodKey));
    final prevStatsAsync = ref.watch(
      hubPeriodLightStatsProvider(_previousPeriodKey),
    );
    final followOverviewAsync = ref.watch(
      hubPeriodFollowOverviewProvider(periodKey),
    );
    final followSnapshotAsync = ref.watch(
      hubPeriodFollowSnapshotProvider(periodKey),
    );
    final updatedOverviewAsync = ref.watch(
      hubPeriodUpdatedOverviewProvider(periodKey),
    );
    final qualityAsync = ref.watch(hubPeriodQualityOverviewProvider(periodKey));
    final scope = periodKey.period;

    return statsAsync.when(
      data: (s) {
        final reception = s.todayCount ?? 0;
        final incomplete = s.incompleteCount ?? 0;
        // reload/refresh 중 이전 스냅샷을 유지해 follow 카드가 0으로 깜빡이지 않게 한다.
        final followSnapshot = followSnapshotAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (snap) => snap,
          loading: () => followSnapshotAsync.valueOrNull,
          error: (_, _) => followSnapshotAsync.valueOrNull,
        );
        final int followCount = followSnapshot?.remaining ??
            followOverviewAsync.valueOrNull?.total ??
            0;
        final followProgressHint = followSnapshot == null
            ? null
            : '전체 ${followSnapshot.total} · 완료 ${followSnapshot.completed} · 남음 ${followSnapshot.remaining}';
        final updatedCount = updatedOverviewAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (o) => o.total,
          loading: () => updatedOverviewAsync.valueOrNull?.total ?? 0,
          error: (_, _) => updatedOverviewAsync.valueOrNull?.total ?? 0,
        );
        final quality = qualityAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (q) => q,
          loading: () => qualityAsync.valueOrNull,
          error: (_, _) => qualityAsync.valueOrNull,
        );
        final prevReception = prevStatsAsync.valueOrNull?.todayCount ?? 0;
        final prevIncomplete = prevStatsAsync.valueOrNull?.incompleteCount ?? 0;
        final previousDayYmd = scope == HubPeriod.day
            ? _previousPeriodKey.anchorYmd
            : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (prevStatsAsync.hasValue) ...[
                        _buildFlowReceptionCompareBanner(
                          scheme: scheme,
                          compareLabel: _comparePeriodLabel(),
                          reception: reception,
                          prevReception: prevReception,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (previousDayYmd != null)
                        _buildPreviousDayUncalledBanner(
                          scheme: scheme,
                          count: prevIncomplete,
                          anchorYmd: previousDayYmd,
                        ),
                      _buildPendingUncalledBanner(scheme),
                      HomeMiniStatsWidget(
                        compact: true,
                        receptionLabel: receptionLabel,
                        incompleteLabel: incompleteLabel,
                        followLabel: followLabel,
                        updatedLabel: updatedLabel,
                        today: reception,
                        incomplete: incomplete,
                        todayFollow: followCount,
                        updated: updatedCount,
                        followProgressHint: followProgressHint,
                        uncalledRateText: quality == null
                            ? '-'
                            : '${(quality.uncalledRate * 100).toStringAsFixed(1)}%',
                        avgFirstResponseText: quality == null
                            ? '-'
                            : _formatMinutes(quality.avgFirstResponseMinutes),
                        onTapToday: () => _openReceptionPicker(scope),
                        onLongPressToday: () =>
                            _openReceptionPicker(scope, forcePicker: true),
                        onTapIncomplete: () => _openIncompletePicker(scope),
                        onLongPressIncomplete: () =>
                            _openIncompletePicker(scope, forcePicker: true),
                        onTapTodayFollow: () => _openFollowPicker(scope),
                        onLongPressTodayFollow: () =>
                            _openFollowPicker(scope, forcePicker: true),
                        onTapUpdated: () => _openUpdatedPicker(scope),
                        onLongPressUpdated: () =>
                            _openUpdatedPicker(scope, forcePicker: true),
                        onTapUncalledRate: () => _openQualityPicker(
                          forUncalledRate: true,
                          scope: scope,
                        ),
                        onTapFirstResponse: () => _openQualityPicker(
                          forUncalledRate: false,
                          scope: scope,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                            if (mounted) await _loadHomeFlowPrefs();
                          },
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: scheme.primary,
                          ),
                          label: Text(
                            '미통화 안내 설정',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),
                      if (_showLongPressHint) ...[
                        const SizedBox(height: 6),
                        Material(
                          color: scheme.secondaryContainer.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 16,
                                  color: scheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '카드 오른쪽 ⋮ 또는 길게 누르면 담당자를 고를 수 있습니다.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '힌트 닫기',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _dismissLongPressHint,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: scheme.onSecondaryContainer
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: LinearProgressIndicator(minHeight: 3)),
      error: (e, _) => LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: HomeFlowErrorPanel(
                  message: koreanErrorMessage(e),
                  onRetry: () {
                    unawaited(
                      refreshHubPeriodFlow(
                        ref,
                        periodKey,
                        previousKey: _previousPeriodKey,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: HomeHubVisual.screenBackground(_section, scheme),
      child: Column(
        children: [
          _buildUnifiedHomeTop(scheme, user),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: HomeHubVisual.sectionTone(
                      _section,
                      scheme,
                    ).accent.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
              ),
              child: PageView(
                controller: _sectionPageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onSectionPageChanged,
                children: [
                  _lazySectionPage(
                    HomeHubSection.flow,
                    _buildFlowBody(scheme, user),
                  ),
                  _lazySectionPage(
                    HomeHubSection.calendar,
                    _buildCalendarBody(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
