import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 달력에서 날짜 팔로우 탭 시 — 좌우 스와이프로 전·후일 팔로우 목록.
class SalesCallDayFollowPagerScreen extends StatefulWidget {
  const SalesCallDayFollowPagerScreen({
    super.key,
    required this.initialDateYmd,
    this.initialAssignee,
  });

  final String initialDateYmd;
  final String? initialAssignee;

  @override
  State<SalesCallDayFollowPagerScreen> createState() =>
      _SalesCallDayFollowPagerScreenState();
}

class _SalesCallDayFollowPagerScreenState
    extends State<SalesCallDayFollowPagerScreen> {
  static final DateTime _epoch = DateTime(2020, 1, 1);

  late final PageController _pageController;
  int _pageIndex = 0;
  late String _selectedAssignee;

  @override
  void initState() {
    super.initState();
    _pageIndex = _ymdToPageIndex(widget.initialDateYmd);
    _pageController = PageController(initialPage: _pageIndex);
    _selectedAssignee = widget.initialAssignee ?? '전체';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _ymdToPageIndex(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return 0;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return 0;
    return DateTime(y, m, d).difference(_epoch).inDays;
  }

  String _pageIndexToYmd(int index) {
    final dt = _epoch.add(Duration(days: index));
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _shortMd(String ymd) {
    final parts = ymd.split('-');
    if (parts.length != 3) return ymd;
    return '${parts[1]}-${parts[2]}';
  }

  String _titleForYmd(String ymd) {
    if (ymd == todayYmdSeoul()) return '오늘 날짜 팔로우';
    return '${_shortMd(ymd)} 날짜 팔로우';
  }

  void _goToPage(int index) {
    if (index == _pageIndex) return;
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentYmd = _pageIndexToYmd(_pageIndex);
    final prevYmd = _pageIndexToYmd(_pageIndex - 1);
    final nextYmd = _pageIndexToYmd(_pageIndex + 1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_titleForYmd(currentYmd)),
            Text(
              formatYmdFlowLabelKo(currentYmd),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            tooltip: '이전 날짜 (${_shortMd(prevYmd)})',
            onPressed: () => _goToPage(_pageIndex - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: '다음 날짜 (${_shortMd(nextYmd)})',
            onPressed: () => _goToPage(_pageIndex + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: 14,
                  color: scheme.onPrimary.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_shortMd(prevYmd)} ← 스와이프 → ${_shortMd(nextYmd)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _pageIndex = index),
        itemBuilder: (context, index) {
          final ymd = _pageIndexToYmd(index);
          return SalesCallListScreen(
            key: ValueKey('day_follow_$ymd'),
            embedded: true,
            mode: ListQueryMode.incompleteByDate,
            date: ymd,
            selectedAssignee: _selectedAssignee,
            onAssigneeChanged: (assignee) {
              if (_selectedAssignee == assignee) return;
              setState(() => _selectedAssignee = assignee);
            },
          );
        },
      ),
    );
  }
}
