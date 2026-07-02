import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_day_follow_pager_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';


/// 홈 [달력] 구역 — 팔로우·예정일 달력.
class HomeFollowCalendarPanel extends ConsumerStatefulWidget {
  const HomeFollowCalendarPanel({
    super.key,
    this.scrollController,
    this.initialCalendarFormat = CalendarFormat.week,
    this.fitSingleScreen = false,
    this.onRefresh,
  });

  final ScrollController? scrollController;
  final CalendarFormat initialCalendarFormat;
  final bool fitSingleScreen;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<HomeFollowCalendarPanel> createState() =>
      _HomeFollowCalendarPanelState();
}

class _HomeFollowCalendarPanelState
    extends ConsumerState<HomeFollowCalendarPanel> {
  DateTime _focusedDay = DateTime.now();
  String _selectedAssignee = '전체';
  late CalendarFormat _calendarFormat;

  /// 사용자가 담당자 칩을 직접 탭한 뒤에는 '전체'를 로그인 담당자로 되돌리지 않음.
  bool _userPickedAssigneeFilter = false;
  List<SalesCall>? _cachedFollowCalls;
  List<TempManagerOverride>? _cachedOverrides;

  static final DateTime _weekEpochMonday = DateTime(2020, 1, 6);
  PageController? _weekPageController;
  int _weekPageIndex = 0;

  DateTime _ymdToDateTime(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  @override
  void initState() {
    super.initState();
    _calendarFormat = widget.initialCalendarFormat == CalendarFormat.month
        ? CalendarFormat.month
        : CalendarFormat.week;
    if (_calendarFormat == CalendarFormat.week) {
      _focusedDay = _ymdToDateTime(todayYmdSeoul());
      _initWeekPageController();
    } else {
      _focusedDay = _ymdToDateTime(ref.read(homeHubFlowAnchorYmdProvider));
      _weekPageController?.dispose();
      _weekPageController = null;
    }
  }

  @override
  void dispose() {
    _weekPageController?.dispose();
    super.dispose();
  }

  int _weekPageIndexFromMonday(String monYmd) {
    final mon = _ymdToDateTime(monYmd);
    return mon.difference(_weekEpochMonday).inDays ~/ 7;
  }

  String _mondayYmdFromWeekPageIndex(int index) {
    final mon = _weekEpochMonday.add(Duration(days: index * 7));
    return _ymdFromDateTime(mon);
  }

  void _initWeekPageController() {
    final mon = seoulWeekRangeContaining(_focusedDayYmd()).$1;
    _weekPageIndex = _weekPageIndexFromMonday(mon);
    _weekPageController?.dispose();
    _weekPageController = PageController(initialPage: _weekPageIndex);
  }

  void _animateToWeekPage(int index) {
    if (index == _weekPageIndex) return;
    final controller = _weekPageController;
    if (controller == null || !controller.hasClients) {
      setState(() {
        _weekPageIndex = index;
        _focusedDay = _ymdToDateTime(_mondayYmdFromWeekPageIndex(index));
      });
      return;
    }
    HapticFeedback.selectionClick();
    controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(HomeFollowCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCalendarFormat != widget.initialCalendarFormat) {
      setState(() {
        _calendarFormat = widget.initialCalendarFormat == CalendarFormat.month
            ? CalendarFormat.month
            : CalendarFormat.week;
        if (_calendarFormat == CalendarFormat.week) {
          _focusedDay = _ymdToDateTime(todayYmdSeoul());
          _initWeekPageController();
        } else {
          _focusedDay = _ymdToDateTime(ref.read(homeHubFlowAnchorYmdProvider));
          _weekPageController?.dispose();
          _weekPageController = null;
        }
      });
    }
  }

  String _weekdayKo(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  bool _isViewingCurrentWeek() {
    final focused = seoulWeekRangeContaining(_focusedDayYmd());
    final current = seoulWeekRangeContaining(todayYmdSeoul());
    return focused.$1 == current.$1 && focused.$2 == current.$2;
  }

  String _focusedWeekRangeLabel() {
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    final range = formatWeekRangeFlowLabel(w.$1, w.$2);
    if (_calendarFormat == CalendarFormat.week && _isViewingCurrentWeek()) {
      return '금주 $range';
    }
    return range;
  }

  void _jumpToThisMonth() {
    final today = todayYmdSeoul();
    setState(() {
      _calendarFormat = CalendarFormat.month;
      _focusedDay = _ymdToDateTime(today);
    });
    _weekPageController?.dispose();
    _weekPageController = null;
  }

  void _jumpToThisWeek() {
    final today = todayYmdSeoul();
    setState(() {
      _calendarFormat = CalendarFormat.week;
      _focusedDay = _ymdToDateTime(today);
    });
    _initWeekPageController();
  }

  void _shiftFocusedWeek(int dir) {
    _animateToWeekPage(_weekPageIndex + dir);
  }

  void _shiftFocusedMonth(int dir) {
    final dt = _focusedDay;
    final next = DateTime(dt.year, dt.month + dir, 1);
    setState(() => _focusedDay = next);
  }

  void _onCalendarPageChanged(DateTime focusedDay) {
    if (_focusedDay.year == focusedDay.year &&
        _focusedDay.month == focusedDay.month &&
        _focusedDay.day == focusedDay.day) {
      return;
    }
    setState(() => _focusedDay = focusedDay);
  }

  String _ymdFromDateTime(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool _isCalendarToday(DateTime day) =>
      _ymdFromDateTime(day) == todayYmdSeoul();

  Map<String, Map<String, int>> _weekAssigneeCountsForMonday(
    String mondayYmd,
    List<SalesCall> followCalls,
    List<TempManagerOverride> overrides,
  ) {
    final keys = weekYmdKeysContaining(mondayYmd);
    final map = {for (final ymd in keys) ymd: <String, int>{}};
    for (final c in followCalls) {
      final fk = c.followCalendarDateKey;
      if (fk == null || fk.length < 10) continue;
      final dateKey = fk.substring(0, 10);
      final bucket = map[dateKey];
      if (bucket == null) continue;
      final assignee = _calendarAssignee(c, overrides);
      if (_selectedAssignee != '전체' && assignee != _selectedAssignee) continue;
      bucket[assignee] = (bucket[assignee] ?? 0) + 1;
    }
    return map;
  }

  Widget _buildWeekPagerBoard({
    required ColorScheme scheme,
    required List<SalesCall> followCalls,
    required List<TempManagerOverride> overrides,
    required Color Function(String) colorForAssignee,
  }) {
    _weekPageController ??= PageController(initialPage: _weekPageIndex);
    return PageView.builder(
      controller: _weekPageController,
      onPageChanged: (index) {
        if (!mounted || index == _weekPageIndex) return;
        HapticFeedback.selectionClick();
        setState(() {
          _weekPageIndex = index;
          _focusedDay = _ymdToDateTime(_mondayYmdFromWeekPageIndex(index));
        });
      },
      itemBuilder: (context, index) {
        final mon = _mondayYmdFromWeekPageIndex(index);
        return _buildVerticalWeekBoard(
          scheme: scheme,
          weekKeys: weekYmdKeysContaining(mon),
          weekAssigneeCounts: _weekAssigneeCountsForMonday(
            mon,
            followCalls,
            overrides,
          ),
          colorForAssignee: colorForAssignee,
        );
      },
    );
  }

  Widget _buildTableCalendarDayCell({
    required ColorScheme scheme,
    required DateTime day,
    required bool isOutside,
    required bool isToday,
    required double fontSize,
  }) {
    Color color = isOutside
        ? scheme.onSurfaceVariant.withValues(alpha: 0.45)
        : scheme.onSurface;
    if (!isOutside) {
      if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
      if (day.weekday == DateTime.sunday) color = Colors.redAccent;
    } else {
      if (day.weekday == DateTime.saturday) {
        color = Colors.blueAccent.withValues(alpha: 0.5);
      }
      if (day.weekday == DateTime.sunday) {
        color = Colors.redAccent.withValues(alpha: 0.5);
      }
    }

    if (isToday) {
      final size = fontSize >= 13 ? 34.0 : 28.0;
      return Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.onPrimary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.38),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: scheme.onPrimary,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isOutside ? FontWeight.w500 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _openDayFollowList(String dateKey) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallDayFollowPagerScreen(
          initialDateYmd: dateKey,
          initialAssignee: _selectedAssignee,
        ),
      ),
    );
  }

  int _todayFollowCount({
    required Map<String, int> dateMarkers,
    required Map<String, Map<String, int>> weekAssigneeCounts,
  }) {
    final today = todayYmdSeoul();
    if (_calendarFormat == CalendarFormat.week) {
      final dayMap = weekAssigneeCounts[today] ?? const <String, int>{};
      if (_selectedAssignee == '전체') {
        return dayMap.values.fold<int>(0, (sum, n) => sum + n);
      }
      return dayMap[_selectedAssignee] ?? 0;
    }
    return dateMarkers[today] ?? 0;
  }

  Widget _buildTodayFollowShortcut(ColorScheme scheme, int todayCount) {
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.lightImpact();
          _openDayFollowList(todayYmdSeoul());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.today_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '오늘 팔로우',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Text(
                '$todayCount건',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAssigneeFilter(String assignee) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAssignee = assignee;
      _userPickedAssigneeFilter = true;
    });
  }

  Widget _buildFitSingleScreenLayout({
    required ColorScheme scheme,
    required List<String> sortedAssignees,
    required Map<String, int> counts,
    required Color Function(String) colorForAssignee,
    required Map<String, int> dateMarkers,
    required int todayFollowCount,
    required List<SalesCall> followCalls,
    required List<TempManagerOverride> overrides,
    Map<String, Map<String, int>> weekAssigneeCounts = const {},
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTodayFollowShortcut(scheme, todayFollowCount),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedAssignees.length,
              itemBuilder: (context, idx) {
                final assignee = sortedAssignees[idx];
                final count = counts[assignee] ?? 0;
                final isSelected = _selectedAssignee == assignee;
                final color = colorForAssignee(assignee);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _selectAssigneeFilter(assignee),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 108),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.16)
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? color.withValues(alpha: 0.45)
                              : scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              assignee,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: color,
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
          const SizedBox(height: 3),
          _buildFitCalendarToolbarRow(scheme),
          const SizedBox(height: 3),
          Expanded(
            child: _calendarFormat == CalendarFormat.week
                ? _buildWeekPagerBoard(
                    scheme: scheme,
                    followCalls: followCalls,
                    overrides: overrides,
                    colorForAssignee: colorForAssignee,
                  )
                : _buildCompactCalendar(
                    scheme: scheme,
                    dateMarkers: dateMarkers,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWeekNav(ColorScheme scheme) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftFocusedWeek(-1),
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Text(
              _focusedWeekRangeLabel(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shiftFocusedWeek(1),
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalWeekBoard({
    required ColorScheme scheme,
    required List<String> weekKeys,
    required Map<String, Map<String, int>> weekAssigneeCounts,
    required Color Function(String) colorForAssignee,
  }) {
    final today = todayYmdSeoul();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < weekKeys.length; i++)
                  Expanded(
                    child: _buildVerticalWeekDayRow(
                      scheme: scheme,
                      dateKey: weekKeys[i],
                      dayMap: weekAssigneeCounts[weekKeys[i]] ?? const {},
                      colorForAssignee: colorForAssignee,
                      isToday: weekKeys[i] == today,
                      showBottomBorder: i < weekKeys.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalWeekDayRow({
    required ColorScheme scheme,
    required String dateKey,
    required Map<String, int> dayMap,
    required Color Function(String) colorForAssignee,
    required bool isToday,
    bool showBottomBorder = false,
  }) {
    final parts = dateKey.split('-');
    final month = parts.length == 3 ? int.tryParse(parts[1]) ?? 0 : 0;
    final dayNum = parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
    final weekday = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? 0, month, dayNum).weekday
        : 1;
    final sorted = dayMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    Color weekdayColor = scheme.onSurfaceVariant;
    if (weekday == DateTime.saturday) weekdayColor = Colors.blueAccent;
    if (weekday == DateTime.sunday) weekdayColor = Colors.redAccent;

    final filteredOnly = _selectedAssignee != '전체';

    return Material(
      color: isToday
          ? scheme.primaryContainer.withValues(alpha: 0.32)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openDayFollowList(dateKey);
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isToday
                    ? scheme.primary
                    : Colors.transparent,
                width: isToday ? 4 : 0,
              ),
              bottom: showBottomBorder
                  ? BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.22),
                    )
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 84,
                padding: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '오늘',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: scheme.onPrimary,
                            height: 1,
                          ),
                        ),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$month/$dayNum(${_weekdayKo(weekday)})',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isToday ? scheme.primary : weekdayColor,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '$total건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: scheme.error,
                      height: 1.05,
                    ),
                  ),
                ),
              Expanded(
                child: total == 0
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '팔로우 없음',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      )
                    : filteredOnly
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_selectedAssignee} ${dayMap[_selectedAssignee] ?? 0}건',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colorForAssignee(_selectedAssignee),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: sorted.map((e) {
                            final c = colorForAssignee(e.key);
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: c.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  '${e.key} ${e.value}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: c,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 홈 단일 화면: 주 이동 + 주간/월간 토글을 한 줄로.
  Widget _buildFitCalendarToolbarRow(ColorScheme scheme) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    final shortcutColor = isWeek ? Colors.teal : Colors.indigo;
    Widget navBtn({required IconData icon, required VoidCallback onTap}) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          minimumSize: const Size(26, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    Widget formatChip({
      required bool selected,
      required String label,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: selected ? activeColor : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (isWeek) ...[
            navBtn(
              icon: Icons.chevron_left_rounded,
              onTap: () => _shiftFocusedWeek(-1),
            ),
            Expanded(
              child: Text(
                _focusedWeekRangeLabel(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            navBtn(
              icon: Icons.chevron_right_rounded,
              onTap: () => _shiftFocusedWeek(1),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ],
          formatChip(
            selected: isWeek,
            label: '주간',
            activeColor: Colors.teal,
            onTap: () {
              HapticFeedback.selectionClick();
              _jumpToThisWeek();
            },
          ),
          const SizedBox(width: 4),
          formatChip(
            selected: !isWeek,
            label: '월간',
            activeColor: Colors.indigo,
            onTap: () {
              HapticFeedback.selectionClick();
              _jumpToThisMonth();
            },
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isWeek ? _jumpToThisWeek : _jumpToThisMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: shortcutColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: shortcutColor.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                isWeek ? '이번주' : '이번달',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: shortcutColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFormatToggleRow(ColorScheme scheme) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    final shortcutColor = isWeek ? Colors.teal : Colors.indigo;

    Widget formatChip({
      required bool selected,
      required String label,
      required IconData icon,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.35)
                    : scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: selected ? activeColor : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? activeColor : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWeek) ...[
            _buildInlineWeekNav(scheme),
            const SizedBox(height: 2),
          ],
          Row(
            children: [
              formatChip(
                selected: isWeek,
                label: '주간',
                icon: Icons.view_week_rounded,
                activeColor: Colors.teal,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _jumpToThisWeek();
                },
              ),
              const SizedBox(width: 4),
              formatChip(
                selected: !isWeek,
                label: '월간',
                icon: Icons.calendar_month_rounded,
                activeColor: Colors.indigo,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _jumpToThisMonth();
                },
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isWeek ? _jumpToThisWeek : _jumpToThisMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: shortcutColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: shortcutColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    isWeek ? '이번주' : '이번달',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: shortcutColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCalendar({
    required ColorScheme scheme,
    required Map<String, int> dateMarkers,
  }) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(4),
      child: TableCalendar(
        key: ValueKey(_calendarFormat),
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.week: '주간',
          CalendarFormat.month: '월간',
        },
        onFormatChanged: (format) {
          if (_calendarFormat == format) return;
          if (format == CalendarFormat.week) {
            _jumpToThisWeek();
          } else {
            _jumpToThisMonth();
          }
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'ko_KR',
        daysOfWeekHeight: isWeek ? 18 : 22,
        rowHeight: isWeek ? 26 : 32,
        availableGestures: AvailableGestures.horizontalSwipe,
        pageAnimationEnabled: true,
        pageAnimationDuration: const Duration(milliseconds: 320),
        pageAnimationCurve: Curves.easeOutCubic,
        pageJumpingEnabled: false,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: EdgeInsets.symmetric(vertical: isWeek ? 2 : 4),
          titleTextStyle: TextStyle(
            fontSize: isWeek ? 12 : 13,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekendStyle: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        calendarStyle: CalendarStyle(
          holidayTextStyle: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
          todayDecoration: const BoxDecoration(shape: BoxShape.circle),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            return _buildTableCalendarDayCell(
              scheme: scheme,
              day: day,
              isOutside: false,
              isToday: _isCalendarToday(day),
              fontSize: 11,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildTableCalendarDayCell(
              scheme: scheme,
              day: day,
              isOutside: true,
              isToday: _isCalendarToday(day),
              fontSize: 11,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildTableCalendarDayCell(
              scheme: scheme,
              day: day,
              isOutside: false,
              isToday: true,
              fontSize: 11,
            );
          },
          markerBuilder: (context, date, events) {
            final dateKey = date.toIso8601String().substring(0, 10);
            final count = dateMarkers[dateKey] ?? 0;
            if (count <= 0) return null;
            return Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() => _focusedDay = focusedDay);
          final dateStr = selectedDay.toIso8601String().substring(0, 10);
          _openDayFollowList(dateStr);
        },
        onPageChanged: _onCalendarPageChanged,
      ),
    );
  }

  Map<String, Color> _assigneeColorMap(
    ColorScheme scheme,
    Iterable<String> assignees,
  ) {
    final sorted = assignees.toList();
    final individuals =
        sorted.where((a) => a != '전체' && a != '미지정').toList();
    final cache = <String, Color>{};
    for (final a in sorted) {
      hubAssigneeColor(
        scheme,
        a,
        cache: cache,
        orderedAssignees: individuals,
      );
    }
    return cache;
  }

  String _calendarAssignee(SalesCall c, List<TempManagerOverride> overrides) {
    return displayAssigneeForCall(c, overrides, DateTime.now());
  }

  String _focusedDayYmd() =>
      '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}-${_focusedDay.day.toString().padLeft(2, '0')}';

  CalendarFollowRangeKey _calendarRangeKey() {
    if (_calendarFormat == CalendarFormat.month) {
      final m = seoulMonthRangeContaining(_focusedDayYmd());
      return (startYmd: m.$1, endYmd: m.$2);
    }
    // 주간 달력 — 표시 주(월~일)만 조회. 월±7일 전건 fetch 제거.
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    return (startYmd: w.$1, endYmd: w.$2);
  }

  Future<void> _refreshCalendarData() async {
    final key = _calendarRangeKey();
    ref.invalidate(calendarFollowRangeProvider(key));
    await ref.read(calendarFollowRangeProvider(key).future);
  }

  List<String> _weekYmdKeys() {
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    final keys = <String>[w.$1];
    var cur = w.$1;
    for (var i = 0; i < 6; i++) {
      cur = addDaysToYmd(cur, 1);
      keys.add(cur);
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeHubFlowAnchorYmdProvider, (prev, next) {
      if (prev == next || next.isEmpty) return;
      final nextDay = _ymdToDateTime(next);
      if (_calendarFormat == CalendarFormat.week) {
        final anchorWeek = seoulWeekRangeContaining(next);
        final focusedWeek = seoulWeekRangeContaining(_focusedDayYmd());
        if (focusedWeek.$1 == anchorWeek.$1) {
          setState(() => _focusedDay = nextDay);
          return;
        }
        final target = _weekPageIndexFromMonday(anchorWeek.$1);
        setState(() => _focusedDay = nextDay);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _animateToWeekPage(target);
        });
        return;
      }
      setState(() => _focusedDay = nextDay);
    });

    final rangeKey = _calendarRangeKey();
    final asyncCalls = ref.watch(calendarFollowRangeProvider(rangeKey));
    final overridesAsync = ref.watch(tempManagerOverridesProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) => overridesAsync.when(
        data: (overrides) {
          _cachedFollowCalls = calls;
          _cachedOverrides = overrides;
          return _buildCalendarShell(
            calls: calls,
            overrides: overrides,
            scheme: scheme,
            rangeKey: rangeKey,
            isRefreshing: false,
          );
        },
        loading: () => _buildCalendarLoadingShell(scheme, rangeKey),
        error: (e, _) => _buildCalendarErrorShell(e, scheme, rangeKey),
      ),
      loading: () => _buildCalendarLoadingShell(scheme, rangeKey),
      error: (e, _) => _buildCalendarErrorShell(e, scheme, rangeKey),
    );
  }

  Widget _buildCalendarLoadingShell(ColorScheme scheme, CalendarFollowRangeKey rangeKey) {
    final cachedCalls = _cachedFollowCalls;
    final cachedOverrides = _cachedOverrides;
    if (cachedCalls != null && cachedOverrides != null) {
      return _buildCalendarShell(
        calls: cachedCalls,
        overrides: cachedOverrides,
        scheme: scheme,
        rangeKey: rangeKey,
        isRefreshing: true,
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildCalendarErrorShell(
    Object error,
    ColorScheme scheme,
    CalendarFollowRangeKey rangeKey,
  ) {
    final cachedCalls = _cachedFollowCalls;
    final cachedOverrides = _cachedOverrides;
    if (cachedCalls != null && cachedOverrides != null) {
      return _buildCalendarShell(
        calls: cachedCalls,
        overrides: cachedOverrides,
        scheme: scheme,
        rangeKey: rangeKey,
        isRefreshing: false,
        errorBanner: koreanErrorMessage(error),
      );
    }
    return Center(child: Text(koreanErrorMessage(error)));
  }

  Widget _buildCalendarShell({
    required List<SalesCall> calls,
    required List<TempManagerOverride> overrides,
    required ColorScheme scheme,
    required CalendarFollowRangeKey rangeKey,
    required bool isRefreshing,
    String? errorBanner,
  }) {
    final onRefresh = widget.onRefresh ?? _refreshCalendarData;
    final body = _buildCalendarBody(calls, overrides, scheme);
    final stacked = Stack(
      children: [
        body,
        if (isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (errorBanner != null)
          Positioned(
            top: isRefreshing ? 2 : 0,
            left: 8,
            right: 8,
            child: Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(8),
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  errorBanner,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.fitSingleScreen) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            color: scheme.secondary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                child: stacked,
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
        child: stacked,
      ),
    );
  }

  Widget _buildCalendarBody(
    List<SalesCall> calls,
    List<TempManagerOverride> overrides,
    ColorScheme scheme,
  ) {
    // API `followRange` + 목록 `incompleteByDate`와 동일 조건(서버에서 이미 미종료·단순문의 제외)
    final followCalls = calls
        .where((c) => c.followCalendarDateKey != null)
        .toList();

    final focusedMonthStr = _focusedDayYmd().substring(0, 7);
    final weekYmdSet = _weekYmdKeys().toSet();

    bool inFocusedPeriod(String? followYmd) {
      if (followYmd == null || followYmd.length < 10) return false;
      final key = followYmd.substring(0, 10);
      if (_calendarFormat == CalendarFormat.month) {
        return key.startsWith(focusedMonthStr);
      }
      return weekYmdSet.contains(key);
    }

    final visibleCallsInPeriod = followCalls
        .where((c) => inFocusedPeriod(c.followCalendarDateKey))
        .toList();

    final Map<String, int> counts = {'전체': visibleCallsInPeriod.length};
    for (var c in visibleCallsInPeriod) {
      final a = _calendarAssignee(c, overrides);
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

    final assigneeColorMap = _assigneeColorMap(scheme, sortedAssignees);
    Color colorForAssignee(String name) =>
        assigneeColorMap[name] ?? hubAssigneeColor(
          scheme,
          name,
          cache: assigneeColorMap,
          orderedAssignees: sortedAssignees
              .where((a) => a != '전체' && a != '미지정')
              .toList(),
        );

    // 최초 진입 시에만 로그인 담당자로 기본 선택 (이후 '전체' 탭은 유지)
    final user = ref.watch(authControllerProvider);
    final userName = user?.name;
    if (!_userPickedAssigneeFilter &&
        _selectedAssignee == '전체' &&
        userName != null &&
        counts.containsKey(userName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _userPickedAssigneeFilter ||
            _selectedAssignee != '전체') {
          return;
        }
        setState(() => _selectedAssignee = userName);
      });
    }

    // 3. Prepare calendar markers (group by date) filtered by selected assignee
    final Map<String, int> dateMarkers = {};
    for (final c in followCalls) {
      final a = _calendarAssignee(c, overrides);
      if (_selectedAssignee != '전체' && a != _selectedAssignee) continue;

      final fk = c.followCalendarDateKey;
      if (fk != null && inFocusedPeriod(fk)) {
        final dateKey = fk.substring(0, 10);
        dateMarkers[dateKey] = (dateMarkers[dateKey] ?? 0) + 1;
      }
    }

    final weekYmdKeys = _weekYmdKeys();
    final Map<String, Map<String, int>> weekAssigneeCounts = {
      for (final ymd in weekYmdKeys) ymd: <String, int>{},
    };
    for (final c in followCalls) {
      final fk = c.followCalendarDateKey;
      if (fk == null || fk.length < 10) continue;
      final dateKey = fk.substring(0, 10);
      final bucket = weekAssigneeCounts[dateKey];
      if (bucket == null) continue;
      final assignee = _calendarAssignee(c, overrides);
      if (_selectedAssignee != '전체' && assignee != _selectedAssignee) continue;
      bucket[assignee] = (bucket[assignee] ?? 0) + 1;
    }

    final todayFollowCount = _todayFollowCount(
      dateMarkers: dateMarkers,
      weekAssigneeCounts: weekAssigneeCounts,
    );

    if (widget.fitSingleScreen) {
      return _buildFitSingleScreenLayout(
        scheme: scheme,
        sortedAssignees: sortedAssignees,
        counts: counts,
        colorForAssignee: colorForAssignee,
        dateMarkers: dateMarkers,
        todayFollowCount: todayFollowCount,
        followCalls: followCalls,
        overrides: overrides,
        weekAssigneeCounts: weekAssigneeCounts,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.secondaryContainer.withValues(alpha: 0.5),
                  scheme.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.secondary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 22,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '팔로우 달력',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        _calendarFormat == CalendarFormat.week
                            ? '주간 일정 · 담당자별 건수'
                            : '월간 일정 · 담당자별 건수',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.75,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildTodayFollowShortcut(scheme, todayFollowCount),
          ),
          // ─── 상단 담당자 필터 바 (캘린더용) ───
          SizedBox(
            height: 38,
            width: double.infinity,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: sortedAssignees.length,
              itemBuilder: (context, idx) {
                final assignee = sortedAssignees[idx];
                final count = counts[assignee] ?? 0;
                final isSelected = _selectedAssignee == assignee;

                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: () => _selectAssigneeFilter(assignee),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorForAssignee(assignee).withValues(alpha: 0.18)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorForAssignee(assignee)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                        border: Border.all(
                          color: isSelected
                              ? colorForAssignee(assignee).withValues(alpha: 0.45)
                              : scheme.outlineVariant.withValues(alpha: 0.3),
                          width: isSelected ? 1.6 : 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colorForAssignee(assignee),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            assignee,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              color: colorForAssignee(assignee),
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorForAssignee(assignee)
                                  : colorForAssignee(
                                      assignee,
                                    ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : colorForAssignee(assignee),
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
          const SizedBox(height: 8),
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
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _jumpToThisWeek,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7),
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
                                        color: Colors.teal.withValues(
                                          alpha: 0.16,
                                        ),
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
                                    color:
                                        _calendarFormat == CalendarFormat.week
                                        ? Colors.teal
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
                          onTap: _jumpToThisMonth,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7),
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
                                        color: Colors.indigo.withValues(
                                          alpha: 0.16,
                                        ),
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
                                    color:
                                        _calendarFormat == CalendarFormat.month
                                        ? Colors.indigo
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
                  onTap: _calendarFormat == CalendarFormat.month
                      ? _jumpToThisMonth
                      : _jumpToThisWeek,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_calendarFormat == CalendarFormat.month
                                  ? Colors.indigo
                                  : Colors.teal)
                              .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            (_calendarFormat == CalendarFormat.month
                                    ? Colors.indigo
                                    : Colors.teal)
                                .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _calendarFormat == CalendarFormat.month ? '이번달' : '이번주',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _calendarFormat == CalendarFormat.month
                            ? Colors.indigo
                            : Colors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              final isWeekView = _calendarFormat == CalendarFormat.week;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isWeekView ? 16 : 24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                padding: EdgeInsets.all(isWeekView ? 6 : 12),
                child: TableCalendar(
                  key: ValueKey(_calendarFormat),
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  availableCalendarFormats: const {
                    CalendarFormat.week: '주간',
                    CalendarFormat.month: '월간',
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat == format) return;
                    setState(() => _calendarFormat = format);
                  },
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  locale: 'ko_KR',
                  daysOfWeekHeight: isWeekView ? 20 : 34,
                  rowHeight: isWeekView ? 28 : 46,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  pageAnimationEnabled: true,
                  pageAnimationDuration: const Duration(milliseconds: 320),
                  pageAnimationCurve: Curves.easeOutCubic,
                  pageJumpingEnabled: false,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    headerPadding: EdgeInsets.symmetric(
                      vertical: isWeekView ? 2 : 8,
                    ),
                    titleTextStyle: TextStyle(
                      fontSize: isWeekView ? 13 : 17,
                      fontWeight: FontWeight.bold,
                    ),
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
                    todayDecoration: const BoxDecoration(shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final txt = _weekdayKo(day.weekday);
                      Color color = scheme.onSurfaceVariant;
                      if (day.weekday == DateTime.saturday)
                        color = Colors.blueAccent;
                      if (day.weekday == DateTime.sunday)
                        color = Colors.redAccent;
                      return Center(
                        child: Text(
                          txt,
                          style: TextStyle(
                            fontSize: isWeekView ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildTableCalendarDayCell(
                        scheme: scheme,
                        day: day,
                        isOutside: false,
                        isToday: _isCalendarToday(day),
                        fontSize: isWeekView ? 12 : 14,
                      );
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      return _buildTableCalendarDayCell(
                        scheme: scheme,
                        day: day,
                        isOutside: true,
                        isToday: _isCalendarToday(day),
                        fontSize: isWeekView ? 12 : 14,
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildTableCalendarDayCell(
                        scheme: scheme,
                        day: day,
                        isOutside: false,
                        isToday: true,
                        fontSize: isWeekView ? 12 : 14,
                      );
                    },
                    markerBuilder: (context, date, events) {
                      final dateKey = date.toIso8601String().substring(0, 10);
                      final count = dateMarkers[dateKey] ?? 0;
                      if (count > 0) {
                        final markerSize = isWeekView ? 14.0 : 18.0;
                        return Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: markerSize,
                            height: markerSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: TextStyle(
                                color: scheme.onError,
                                fontSize: isWeekView ? 8 : 9,
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
                    final dateStr = selectedDay.toIso8601String().substring(
                      0,
                      10,
                    );
                    _openDayFollowList(dateStr);
                  },
                  onPageChanged: _onCalendarPageChanged,
                ),
              );
            },
          ),
          if (_calendarFormat == CalendarFormat.week) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.view_week_rounded,
                        size: 12,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '주간 상세',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...weekYmdKeys.map((dateKey) {
                    final dayMap =
                        weekAssigneeCounts[dateKey] ?? const <String, int>{};
                    final total = dayMap.values.fold<int>(
                      0,
                      (sum, v) => sum + v,
                    );
                    final sorted = dayMap.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final parts = dateKey.split('-');
                    final month = parts.length == 3
                        ? int.tryParse(parts[1]) ?? 0
                        : 0;
                    final dayNum = parts.length == 3
                        ? int.tryParse(parts[2]) ?? 0
                        : 0;
                    final weekday = parts.length == 3
                        ? DateTime(
                            int.tryParse(parts[0]) ?? 0,
                            month,
                            dayNum,
                          ).weekday
                        : 1;
                    final isToday = dateKey == todayYmdSeoul();

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
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? scheme.primaryContainer.withValues(alpha: 0.25)
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                                ? scheme.primary.withValues(alpha: 0.45)
                                : scheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              child: Text(
                                '$month/$dayNum (${_weekdayKo(weekday)})',
                                style: TextStyle(
                                  fontSize: 9,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: isToday
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: total == 0
                                  ? Text(
                                      '데이터 없음',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.75),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: sorted
                                          .map(
                                            (e) => Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          SalesCallListScreen(
                                                            mode: ListQueryMode
                                                                .incompleteByDate,
                                                            date: dateKey,
                                                            initialAssignee:
                                                                e.key,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colorForAssignee(
                                                      e.key,
                                                    ).withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${e.key} ${e.value}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: colorForAssignee(
                                                        e.key,
                                                      ),
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
                              width: 30,
                              child: Text(
                                '$total건',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.error,
                                ),
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
    );
  }
}
