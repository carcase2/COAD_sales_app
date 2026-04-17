import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/home/home_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_search_delegate.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.heroTag,
    required this.color,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String heroTag;
  final Color color;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedIndices = {0}; // 초기에 로드할 인덱스 (홈)
  bool _quickActionsOpen = false;
  final ScrollController _quickActionsScrollCtrl = ScrollController();
  bool _quickHasMoreAbove = false;
  bool _quickHasMoreBelow = false;

  @override
  void initState() {
    super.initState();
    // 1. Handle deep link if app was opened via notification (Cold Start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.handleInitialMessage();
      AppUpdateService.checkAndUpdateIfNeeded(context);
    });

    // 상담현황(미통화/달력)이 쓰는 대량 목록을 백그라운드로 미리 불러 탭 전환 시 빨리 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(rankingCallsProvider.future));
    });

    // 2. Sync FCM token with Supabase for the current user
    final user = ref.read(authControllerProvider);
    if (user != null) {
      NotificationService.updateTokenInSupabase(user.id);
      NotificationService.listenToTokenRefresh(user.id);
    }
  }

  @override
  void dispose() {
    _quickActionsScrollCtrl.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _quickActionsOpen = false;
      _currentIndex = index;
      _loadedIndices.add(index); // 선택한 탭을 로드 목록에 추가
    });
  }

  void _refreshQuickHints() {
    if (!_quickActionsOpen || !_quickActionsScrollCtrl.hasClients) {
      if (_quickHasMoreAbove || _quickHasMoreBelow) {
        setState(() {
          _quickHasMoreAbove = false;
          _quickHasMoreBelow = false;
        });
      }
      return;
    }
    final pos = _quickActionsScrollCtrl.position;
    final nextAbove = pos.pixels > 1;
    final nextBelow = pos.pixels < (pos.maxScrollExtent - 1);
    if (nextAbove != _quickHasMoreAbove || nextBelow != _quickHasMoreBelow) {
      setState(() {
        _quickHasMoreAbove = nextAbove;
        _quickHasMoreBelow = nextBelow;
      });
    }
  }

  bool _handleGlobalScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final notifier = ref.read(bottomBarVisibilityProvider.notifier);
    if (n.direction == ScrollDirection.reverse) {
      notifier.state = false;
    } else if (n.direction == ScrollDirection.forward) {
      notifier.state = true;
    }
    return false;
  }

  List<Widget> _buildScreens() {
    return [
      const HomeHubScreen(),
      _loadedIndices.contains(1) ? const ConsultationStatusScreen() : const SizedBox.shrink(),
      _loadedIndices.contains(2) ? const QuoterScreen(showQuickActions: false) : const SizedBox.shrink(),
      _loadedIndices.contains(3) ? const IssuanceRequestScreen() : const SizedBox.shrink(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingConsultationLaunchProvider, (prev, next) {
      if (next == null) return;
      setState(() {
        _currentIndex = 1;
        _loadedIndices.add(1);
      });
    });

    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider);
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 12.0 + safeBottom;
    final quickActions = <_QuickActionItem>[
      _QuickActionItem(
        heroTag: 'global_home_open',
        color: Colors.blueGrey.shade700,
        tooltip: '홈',
        icon: Icons.home_rounded,
        onTap: () {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          _onTabSelected(0);
        },
      ),
      _QuickActionItem(
        heroTag: 'global_call_create',
        color: scheme.tertiary,
        tooltip: '접수',
        icon: Icons.add_ic_call_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SalesCallCreateScreen()),
          );
        },
      ),
      _QuickActionItem(
        heroTag: 'global_issuance_create',
        color: Colors.indigo.shade600,
        tooltip: '발행요청',
        icon: Icons.receipt_long_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          _onTabSelected(3);
          await Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (_) => const IssuanceRequestCreateScreen(
                initialDomain: IssuanceDomain.taxInvoice,
              ),
            ),
          );
        },
      ),
      _QuickActionItem(
        heroTag: 'global_quoter_open',
        color: Colors.teal.shade600,
        tooltip: '견적기',
        icon: Icons.calculate_rounded,
        onTap: () {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          _onTabSelected(2);
        },
      ),
      _QuickActionItem(
        heroTag: 'global_incomplete_open',
        color: Colors.orange.shade700,
        tooltip: '미통화',
        icon: Icons.pending_actions_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallListScreen(
                mode: ListQueryMode.incomplete,
                date: todayYmdSeoul(),
              ),
            ),
          );
        },
      ),
      _QuickActionItem(
        heroTag: 'global_today_follow_open',
        color: Colors.deepPurple.shade600,
        tooltip: '금일팔로우',
        icon: Icons.event_note_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallListScreen(
                mode: ListQueryMode.incompleteByDate,
                date: todayYmdSeoul(),
                initialAssignee: '전체',
              ),
            ),
          );
        },
      ),
      _QuickActionItem(
        heroTag: 'global_consultation_calendar_week',
        color: Colors.green.shade700,
        tooltip: '달력',
        icon: Icons.calendar_view_week_rounded,
        onTap: () {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          requestConsultationCalendarWeekNavigation(ref);
        },
      ),
    ];

    return Scaffold(
      key: scaffoldKey,
      drawer: _buildDrawer(context, user, scheme),
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _onTabSelected(0),
          child: _currentIndex == 0
              ? _buildBrandTitle()
              : Text(
                  _currentIndex == 1 ? '상담현황' : (_currentIndex == 2 ? '견적기' : '발급요청'),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
        ),
        centerTitle: true,
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
          tooltip: '메뉴 열기',
        ),
        actions: [
          if (_currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.home_rounded),
              onPressed: () => _onTabSelected(0),
              tooltip: '홈으로 이동',
            ),
          Center(
            child: Text(
              'v$kAppVersion',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              final repository = ref.read(salesCallsRepositoryProvider);
              final calls = ref.read(todayCallsContentProvider).value ?? [];
              showSearch(
                context: context,
                delegate: SalesCallSearchDelegate(
                  initialItems: calls,
                  repository: repository,
                ),
              );
            },
            tooltip: '통합 검색',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _buildScreens(),
          ),
          if (_quickActionsOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _quickActionsOpen = false),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            right: 16,
            bottom: actionsBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_quickActionsOpen)
                  Container(
                    key: const ValueKey('quick_actions_scroll_panel'),
                    width: 182,
                    constraints: const BoxConstraints(maxHeight: 320),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_quickHasMoreAbove)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text('위에 메뉴 더 있음', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              _refreshQuickHints();
                              return false;
                            },
                            child: SingleChildScrollView(
                              controller: _quickActionsScrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: quickActions
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Material(
                                          color: item.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: item.onTap,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Icon(item.icon, size: 18, color: item.color),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      item.tooltip,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: scheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                  Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        if (_quickHasMoreBelow)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text('아래 메뉴 더 있음', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                FloatingActionButton(
                  heroTag: 'global_actions_toggle',
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  mini: true,
                  onPressed: () {
                    setState(() => _quickActionsOpen = !_quickActionsOpen);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuickHints());
                  },
                  tooltip: _quickActionsOpen ? '닫기' : '열기',
                  child: Icon(_quickActionsOpen ? Icons.close_rounded : Icons.menu_open_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppUser? user, ColorScheme scheme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
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
              image: const DecorationImage(
                image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.05,
              ),
            ),
          ),
          _buildDrawerSectionTitle('메인 메뉴', scheme),
          _buildDrawerItem(
            icon: Icons.home_rounded,
            title: '홈',
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(0);
            },
            scheme: scheme,
          ),
          _buildDrawerItem(
            icon: Icons.assignment_rounded,
            title: '상담현황',
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(1);
            },
            scheme: scheme,
          ),
          _buildDrawerItem(
            icon: Icons.calculate_rounded,
            title: '견적기',
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(2);
            },
            scheme: scheme,
          ),
          _buildDrawerItem(
            icon: Icons.receipt_long_rounded,
            title: '발급요청',
            onTap: () {
              Navigator.pop(context);
              _onTabSelected(3);
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
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Text(
              'COAD Sales App v$kAppVersion',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.door_front_door_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'COAD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              TextSpan(
                text: ' DOOR',
                style: TextStyle(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navIssuanceIcon({required bool selected}) {
    if (!selected) return const Icon(Icons.receipt_long_outlined);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade500, Colors.deepOrange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
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

}
