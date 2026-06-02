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
  int _assigneeScrollNonce = 0;

  @override
  void initState() {
    super.initState();
    _pageIndex = _ymdToPageIndex(widget.initialDateYmd);
    _pageController = PageController(initialPage: _pageIndex);
    _selectedAssignee = widget.initialAssignee ?? '전체';
    if (_selectedAssignee != '전체') {
      _bumpAssigneeScrollNonce();
    }
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
    if (ymd == todayYmdSeoul()) return '오늘 팔로우';
    return '${formatYmdFlowLabelKo(ymd)} 팔로우';
  }

  void _bumpAssigneeScrollNonce() {
    _assigneeScrollNonce++;
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

  void _goToToday() {
    final todayIndex = _ymdToPageIndex(todayYmdSeoul());
    _goToPage(todayIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentYmd = _pageIndexToYmd(_pageIndex);
    final prevYmd = _pageIndexToYmd(_pageIndex - 1);
    final nextYmd = _pageIndexToYmd(_pageIndex + 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForYmd(currentYmd)),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          TextButton(
            onPressed: _goToToday,
            child: Text(
              '오늘',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimary,
              ),
            ),
          ),
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
        onPageChanged: (index) {
          setState(() {
            _pageIndex = index;
            _bumpAssigneeScrollNonce();
          });
        },
        itemBuilder: (context, index) {
          final ymd = _pageIndexToYmd(index);
          return SalesCallListScreen(
            key: ValueKey('day_follow_$ymd'),
            embedded: true,
            mode: ListQueryMode.incompleteByDate,
            date: ymd,
            selectedAssignee: _selectedAssignee,
            assigneeScrollNonce: _assigneeScrollNonce,
            onAssigneeChanged: (assignee) {
              if (_selectedAssignee == assignee) return;
              setState(() {
                _selectedAssignee = assignee;
                _bumpAssigneeScrollNonce();
              });
            },
          );
        },
      ),
    );
  }
}
