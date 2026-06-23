import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_search_delegate.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/navigation/app_menu.dart';
import 'package:coad_customer_calls/navigation/app_menu_drawer.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/providers/app_update_provider.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen>
    with WidgetsBindingObserver {
  static const int _homeTabIndex = 0;
  static const int _issuanceTabIndex = 1;
  static const int _navHomeIndex = 0;
  static const int _navReceptionIndex = 1;
  static const int _navIssuanceIndex = 2;
  static const int _navMenuIndex = 3;
  int _currentIndex = 0;
  int _navSelectedIndex = _navHomeIndex;
  final Set<int> _loadedIndices = {0}; // 초기에 로드할 인덱스 (홈)
  /// 홈에서 연속 뒤로가기 시 앱 종료(스낵바 안내 후 2초 이내 재입력)
  DateTime? _lastBackExitHintAt;

  /// 홈 상단 배너 [닫기] 시 해당 원격 버전은 다시 띄우지 않음.
  String? _dismissedUpdateBannerVersion;
  RealtimeChannel? _issuanceCompletionWatchChannel;
  Timer? _issuanceCompletionDebounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1. Handle deep link if app was opened via notification (Cold Start)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(NotificationService.handleInitialMessage());
      await AppUpdateService.checkAndUpdateIfNeeded(
        context,
        promptOptionalUpdate: false,
      );
      if (mounted) {
        ref.invalidate(appUpdateStatusProvider);
        await ref.read(appUpdateStatusProvider.future);
      }
    });

    // 흐름 프리페치 후 여유 있을 때 미통화 breakdown·발급 감시 (첫 화면 네트워크 혼잡 완화)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        unawaited(
          ref.read(
            incompleteBreakdownCallsProvider((
              period: IncompleteSummaryPeriod.today,
              anchorYmd: todayYmdSeoul(),
            )).future,
          ),
        );
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        _startIssuanceCompletionWatcher();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        ref.read(issuanceBadgeLoadEnabledProvider.notifier).state = true;
      });
    });

    // 2. Sync FCM token with Supabase for the current user
    final user = ref.read(authControllerProvider);
    if (user != null) {
      unawaited(NotificationService.updateTokenInSupabase(user.id));
      NotificationService.listenToTokenRefresh(user.id);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService.onAppResumed());
      final user = ref.read(authControllerProvider);
      if (user != null) {
        unawaited(NotificationService.updateTokenInSupabase(user.id));
      }
      ref.invalidate(appUpdateStatusProvider);
      if (mounted) {
        unawaited(() async {
          await ref.read(appUpdateStatusProvider.future);
          if (!mounted) return;
          await AppUpdateService.checkWhileInUse(context);
        }());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _issuanceCompletionDebounce?.cancel();
    final channel = _issuanceCompletionWatchChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
      _issuanceCompletionWatchChannel = null;
    }
    super.dispose();
  }

  void _startIssuanceCompletionWatcher() {
    unawaited(_checkIssuanceCompletionAndNotify());
    unawaited(_checkIssuanceRequestAndNotify());
    _issuanceCompletionWatchChannel?.unsubscribe();
    _issuanceCompletionWatchChannel = Supabase.instance.client
        .channel('issuance-completion-watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tax_invoices',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tax_invoices',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'performance_bonds',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'performance_bonds',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tax_invoice_issues',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tax_invoice_issues',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'performance_bond_issues',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'performance_bond_issues',
          callback: (_) => _scheduleIssuanceWatchCheck(),
        )
        .subscribe();
  }

  void _scheduleIssuanceWatchCheck() {
    _issuanceCompletionDebounce?.cancel();
    _issuanceCompletionDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(_runIssuanceWatchCheck());
    });
  }

  Future<void> _runIssuanceWatchCheck() async {
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
    try {
      await Future.wait([
        ref.refresh(issuanceAllRowsProvider(IssuanceDomain.taxInvoice).future),
        ref.refresh(issuanceAllRowsProvider(IssuanceDomain.performanceBond).future),
      ]);
    } catch (_) {
      // refetch 실패 시에도 감시 로직은 한 번 시도
    }
    await _checkIssuanceCompletionAndNotify();
    await _checkIssuanceRequestAndNotify();
  }

  Future<void> _checkIssuanceCompletionAndNotify() async {
    try {
      final prefs = ref.read(appDependenciesProvider).prefs;
      const initKey = 'issuance_completion_watch_initialized_v1';
      const seenKey = 'issuance_completion_seen_keys_v1';

      final taxCompleted = await ref.read(
        issuanceCompletedRowsProvider(IssuanceDomain.taxInvoice).future,
      );
      final bondCompleted = await ref.read(
        issuanceCompletedRowsProvider(IssuanceDomain.performanceBond).future,
      );
      final allCompleted = [...taxCompleted, ...bondCompleted];

      String rowKey(IssuanceRequestRow row) {
        final masterId = (row.master['id'] ?? '').toString();
        final issueId = (row.issue?['id'] ?? '').toString();
        return '${row.domain.name}:$masterId:$issueId';
      }

      final currentKeys = allCompleted.map(rowKey).toSet();
      final seenKeys = (prefs.getStringList(seenKey) ?? const <String>[])
          .toSet();
      final initialized = prefs.getBool(initKey) ?? false;

      if (!initialized) {
        await prefs.setBool(initKey, true);
        await prefs.setStringList(seenKey, currentKeys.toList());
        return;
      }

      final newKeys = currentKeys.difference(seenKeys);
      if (newKeys.isEmpty) return;

      // 로컬 알림은 FCM(또는 포그라운드 원격 알림)이 담당 — seen 키만 동기화.

      final merged = seenKeys.union(currentKeys).toList();
      await prefs.setStringList(seenKey, merged);
    } catch (_) {
      // 감시 실패 시 UI 영향 없이 다음 주기에 재시도
    }
  }

  Future<void> _checkIssuanceRequestAndNotify() async {
    try {
      final prefs = ref.read(appDependenciesProvider).prefs;
      const initKey = 'issuance_request_watch_initialized_v1';
      const seenKey = 'issuance_request_seen_keys_v1';

      final taxPending = await ref.read(
        issuanceRequestRowsProvider(IssuanceDomain.taxInvoice).future,
      );
      final bondPending = await ref.read(
        issuanceRequestRowsProvider(IssuanceDomain.performanceBond).future,
      );
      final allPending = [...taxPending, ...bondPending];

      String rowKey(IssuanceRequestRow row) {
        final masterId = (row.master['id'] ?? '').toString();
        final issueId = (row.issue?['id'] ?? '').toString();
        return '${row.domain.name}:$masterId:$issueId';
      }

      final currentKeys = allPending.map(rowKey).toSet();
      final seenKeys = (prefs.getStringList(seenKey) ?? const <String>[])
          .toSet();
      final initialized = prefs.getBool(initKey) ?? false;

      if (!initialized) {
        await prefs.setBool(initKey, true);
        await prefs.setStringList(seenKey, currentKeys.toList());
        return;
      }

      final newKeys = currentKeys.difference(seenKeys);
      if (newKeys.isEmpty) return;

      final user = ref.read(authControllerProvider);
      final isAdmin = user?.role == 'admin';

      for (final row in allPending) {
        final key = rowKey(row);
        if (!newKeys.contains(key)) continue;
        if (!isAdmin && !issuanceIsOwnRequest(row, user?.name)) continue;
        final isTax = row.domain == IssuanceDomain.taxInvoice;
        final isUrgent = isTax && (row.issue?['is_urgent'] ?? false) == true;
        final statusRaw = (row.master['status'] ?? '').toString().toLowerCase();
        final isPartialFollowUp =
            isTax && statusRaw == 'in_progress' && row.issue != null;
        final issuePct = row.issue?['percentage'];
        final pct = issuePct is num
            ? issuePct.toDouble()
            : double.tryParse('$issuePct');
        final name = isTax
            ? (row.master['customer_name'] ?? '요청 건').toString()
            : (row.master['company_name'] ?? row.master['bond_type'] ?? '요청 건')
                  .toString();
        final urgentPrefix = isUrgent ? '🚨 [긴급] ' : '';
        final partialLabel = isPartialFollowUp ? ' 부분' : '';
        final title =
            '${urgentPrefix}${isTax ? '세금계산서' : '이행증권'}$partialLabel 발급요청';
        final body = isPartialFollowUp && pct != null
            ? '$name · ${pct.round()}% 발급요청이 등록되었습니다.'
            : '$name 건의 발급요청이 등록되었습니다.';
        await NotificationService.showIssuanceRequestAlert(
          title: title,
          body: body,
          domain: row.domain,
          masterId: (row.master['id'] ?? '').toString(),
          issueId: (row.issue?['id'] ?? '').toString(),
        );
      }

      final merged = seenKeys.union(currentKeys).toList();
      await prefs.setStringList(seenKey, merged);
    } catch (_) {
      // 감시 실패 시 UI 영향 없이 다음 주기에 재시도
    }
  }

  void _openHomeFlowToday() {
    ref.read(homeHubFlowResetTickProvider.notifier).state++;
    requestHomeHubSection(ref, HomeHubSection.flow);
    _selectHomeTab();
  }

  void _selectHomeTab() {
    if (_navSelectedIndex == _navHomeIndex && _currentIndex == _homeTabIndex) {
      return;
    }
    if (_currentIndex != _homeTabIndex) {
      ref.read(homeHubFlowResetTickProvider.notifier).state++;
    }
    ref.invalidate(appUpdateStatusProvider);
    setState(() {
      _navSelectedIndex = _navHomeIndex;
      _currentIndex = _homeTabIndex;
    });
  }

  void _selectIssuanceTab() {
    ref.read(issuanceBadgeLoadEnabledProvider.notifier).state = true;
    _loadedIndices.add(_issuanceTabIndex);
    if (_navSelectedIndex == _navIssuanceIndex &&
        _currentIndex == _issuanceTabIndex) {
      return;
    }
    setState(() {
      _navSelectedIndex = _navIssuanceIndex;
      _currentIndex = _issuanceTabIndex;
      _loadedIndices.add(_issuanceTabIndex);
      _lastBackExitHintAt = null;
    });
  }

  void _syncNavFromCurrentTab() {
    setState(() {
      _navSelectedIndex = _currentIndex == _issuanceTabIndex
          ? _navIssuanceIndex
          : _navHomeIndex;
    });
  }

  void _openMenuDrawer() {
    HapticFeedback.lightImpact();
    setState(() => _navSelectedIndex = _navMenuIndex);
    ref.read(mainScaffoldKeyProvider).currentState?.openDrawer();
  }

  void _onNavDestinationSelected(int navIndex) {
    if (navIndex == _navMenuIndex) {
      _openMenuDrawer();
      return;
    }
    if (navIndex == _navReceptionIndex) {
      final prevNav = _navSelectedIndex;
      setState(() => _navSelectedIndex = _navReceptionIndex);
      unawaited(
        _openReceptionCreate().whenComplete(() {
          if (!mounted) return;
          if (_currentIndex == _homeTabIndex) {
            setState(() => _navSelectedIndex = prevNav);
          }
        }),
      );
      return;
    }
    if (navIndex == _navHomeIndex) {
      // 홈 재탭 시 금일 흐름으로 빠르게 복귀
      if (_currentIndex == _homeTabIndex &&
          _navSelectedIndex == _navHomeIndex) {
        _openHomeFlowToday();
        return;
      }
      _selectHomeTab();
    } else if (navIndex == _navIssuanceIndex) {
      _selectIssuanceTab();
    }
  }

  Future<void> _openReceptionCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kSalesCallCreateRouteName),
        builder: (_) => const SalesCallCreateScreen(),
      ),
    );
  }

  Future<void> _openReceptionQuickActions() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_ic_call_rounded),
                title: const Text('일반 접수 등록'),
                onTap: () => Navigator.of(context).pop('create'),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: const Text('금일 접수 목록'),
                onTap: () => Navigator.of(context).pop('today'),
              ),
              ListTile(
                leading: const Icon(Icons.phone_missed_rounded),
                title: const Text('금일 미통화 목록'),
                onTap: () => Navigator.of(context).pop('incomplete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'create':
        unawaited(_openReceptionCreate());
      case 'today':
        await _openTodayReceptionList();
      case 'incomplete':
        await _openTodayIncompleteList();
    }
  }

  Future<void> _openTodayReceptionList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.today,
          date: todayYmdSeoul(),
        ),
      ),
    );
  }

  Future<void> _openTodayIncompleteList() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incomplete,
          date: todayYmdSeoul(),
        ),
      ),
    );
  }

  List<Widget> _buildScreens() => [
    const HomeHubScreen(),
    _loadedIndices.contains(_issuanceTabIndex)
        ? const IssuanceRequestScreen()
        : const SizedBox.shrink(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingConsultationLaunchProvider, (prev, next) {
      if (next == null) return;
      _selectHomeTab();
    });
    ref.listen(pendingIssuanceLaunchProvider, (prev, next) {
      if (next == null || !context.mounted) return;
      _selectIssuanceTab();
    });

    final scheme = Theme.of(context).colorScheme;
    final tabAccent = scheme.primary;
    final appBarBg = Color.lerp(scheme.primary, Colors.black, 0.12)!;
    final user = ref.watch(authControllerProvider);
    final updateStatus = ref.watch(appUpdateStatusProvider).valueOrNull;
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);
    final latestRemote = updateStatus?.latestVersion;
    final hasOptionalUpdate =
        updateStatus?.hasUpdate == true && updateStatus?.forceUpdate != true;
    final onHomeTab =
        _currentIndex == _homeTabIndex && _navSelectedIndex == _navHomeIndex;
    final bannerDismissKey = latestRemote ?? '__play_update__';
    final showUpdateBanner =
        onHomeTab &&
        hasOptionalUpdate &&
        bannerDismissKey != _dismissedUpdateBannerVersion;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        final sm = scaffoldKey.currentState;
        if (sm != null && sm.isDrawerOpen) {
          sm.closeDrawer();
          return;
        }

        if (_currentIndex != _homeTabIndex) {
          _selectHomeTab();
          return;
        }

        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }

        final now = DateTime.now();
        const exitWindow = Duration(seconds: 2);
        if (_lastBackExitHintAt != null &&
            now.difference(_lastBackExitHintAt!) < exitWindow) {
          SystemNavigator.pop();
          return;
        }
        _lastBackExitHintAt = now;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('뒤로가기를 한 번 더 누르면 앱이 종료됩니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        key: scaffoldKey,
        onDrawerChanged: (isOpen) {
          if (!isOpen && _navSelectedIndex == _navMenuIndex) {
            _syncNavFromCurrentTab();
          }
        },
        drawer: _buildAppMenuDrawer(context, user, scheme, updateStatus),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openHomeFlowToday,
                child: _buildBrandTitle(),
              ),
              if (updateStatus?.hasUpdate == true) ...[
                const SizedBox(width: 8),
                _buildLogoUpdateChip(
                  latestVersion: latestRemote,
                  forceUpdate: updateStatus?.forceUpdate == true,
                  onTap: () => AppUpdateService.checkAndUpdateIfNeeded(
                    context,
                    forceRecheck: true,
                  ),
                ),
              ],
            ],
          ),
          centerTitle: true,
          backgroundColor: appBarBg,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
            tooltip: '메뉴 열기',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: Colors.white,
              ),
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tabAccent.withValues(alpha: 0.35),
                    tabAccent,
                    tabAccent.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _buildScreens()),
            if (showUpdateBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildUpdateAvailableBanner(
                  scheme: scheme,
                  latestVersion: latestRemote,
                  onUpdate: () => AppUpdateService.checkAndUpdateIfNeeded(
                    context,
                    forceRecheck: true,
                  ),
                  onDismiss: () => setState(
                    () => _dismissedUpdateBannerVersion = bannerDismissKey,
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _MainBottomNavBar(
          selectedIndex: _navSelectedIndex,
          issuanceBadgeAsync: ref.watch(
            issuanceRequestBadgeCountVisibleProvider,
          ),
          onTapHome: () => _onNavDestinationSelected(_navHomeIndex),
          onLongPressHome: _openHomeFlowToday,
          onTapReception: () => _onNavDestinationSelected(_navReceptionIndex),
          onLongPressReception: _openReceptionQuickActions,
          onTapIssuance: () => _onNavDestinationSelected(_navIssuanceIndex),
          onTapMenu: () => _onNavDestinationSelected(_navMenuIndex),
        ),
      ),
    );
  }

  AppMenuCatalog _buildMenuCatalog(
    BuildContext context,
    AppUpdateStatus? updateStatus,
  ) {
    void closeDrawerThen(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    return AppMenuCatalog(
      sections: const [
        AppMenuSection(id: 'main', title: '업무'),
        AppMenuSection(id: 'lists', title: '목록·검색'),
        AppMenuSection(id: 'system', title: '시스템'),
      ],
      entries: [
        AppMenuEntry(
          id: 'home',
          sectionId: 'main',
          icon: Icons.home_rounded,
          title: '홈 · 업무 흐름',
          subtitle: '금일·금주·금월 통계',
          keywords: const ['흐름', '통계', '상담'],
          onTap: () => closeDrawerThen(() {
            _selectHomeTab();
            requestHomeHubSection(ref, HomeHubSection.flow);
          }),
        ),
        AppMenuEntry(
          id: 'home_incomplete',
          sectionId: 'main',
          icon: Icons.phone_missed_rounded,
          title: '미통화 현황',
          subtitle: '담당자별 미통화·비율',
          quickAccess: true,
          quickLabel: '미통화',
          keywords: const ['미통화', '미결', '콜'],
          onTap: () => closeDrawerThen(() {
            _selectHomeTab();
            requestHomeHubSection(ref, HomeHubSection.incomplete);
          }),
        ),
        AppMenuEntry(
          id: 'home_calendar',
          sectionId: 'main',
          icon: Icons.calendar_month_rounded,
          title: '상담 달력',
          subtitle: '주간·월간 팔로우 일정',
          quickAccess: true,
          quickLabel: '달력',
          keywords: const ['달력', '일정', '팔로우'],
          onTap: () => closeDrawerThen(() {
            _selectHomeTab();
            requestHomeHubSection(
              ref,
              HomeHubSection.calendar,
              calendarFormat: CalendarFormat.week,
            );
          }),
        ),
        AppMenuEntry(
          id: 'reception_create',
          sectionId: 'main',
          icon: Icons.add_ic_call_rounded,
          title: '접수 등록',
          quickAccess: true,
          quickLabel: '접수',
          keywords: const ['신규', '전화', '접수'],
          onTap: () => closeDrawerThen(() => unawaited(_openReceptionCreate())),
        ),
        AppMenuEntry(
          id: 'issuance',
          sectionId: 'main',
          icon: Icons.receipt_long_rounded,
          title: '발급요청',
          subtitle: '세금계산서·이행증권',
          keywords: const ['세금', '이행', '발급'],
          onTap: () => closeDrawerThen(_selectIssuanceTab),
        ),
        AppMenuEntry(
          id: 'reception_today',
          sectionId: 'lists',
          icon: Icons.list_alt_rounded,
          title: '금일 접수 목록',
          keywords: const ['목록', '오늘', '접수'],
          onTap: () =>
              closeDrawerThen(() => unawaited(_openTodayReceptionList())),
        ),
        AppMenuEntry(
          id: 'reception_incomplete_today',
          sectionId: 'lists',
          icon: Icons.phone_callback_rounded,
          title: '금일 미통화 목록',
          keywords: const ['미통화', '목록'],
          onTap: () =>
              closeDrawerThen(() => unawaited(_openTodayIncompleteList())),
        ),
        AppMenuEntry(
          id: 'search',
          sectionId: 'lists',
          icon: Icons.search_rounded,
          title: '통합 검색',
          subtitle: '고객·접수 건 검색',
          quickAccess: true,
          quickLabel: '검색',
          keywords: const ['검색', '고객', '찾기'],
          onTap: () => closeDrawerThen(() {
            final repository = ref.read(salesCallsRepositoryProvider);
            final calls = ref.read(todayCallsContentProvider).value ?? [];
            showSearch(
              context: context,
              delegate: SalesCallSearchDelegate(
                initialItems: calls,
                repository: repository,
              ),
            );
          }),
        ),
        AppMenuEntry(
          id: 'settings',
          sectionId: 'system',
          icon: Icons.settings_outlined,
          title: '설정',
          badge: updateStatus?.hasUpdate == true ? '업데이트' : null,
          keywords: const ['환경', '업데이트', '미통화 안내'],
          onTap: () => closeDrawerThen(() {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          }),
        ),
        AppMenuEntry(
          id: 'logout',
          sectionId: 'system',
          icon: Icons.logout,
          title: '로그아웃',
          onTap: () async {
            Navigator.pop(context);
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('로그아웃'),
                content: const Text('정말 로그아웃 하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(authControllerProvider.notifier).logout();
            }
          },
        ),
      ],
    );
  }

  Widget _buildAppMenuDrawer(
    BuildContext context,
    AppUser? user,
    ColorScheme scheme,
    AppUpdateStatus? updateStatus,
  ) {
    return AppMenuDrawer(
      catalog: _buildMenuCatalog(context, updateStatus),
      accountName: '${user?.name ?? '사용자'} 님',
      accountSubtitle: '사번/ID: ${user?.id ?? '-'}',
      headerDecoration: BoxDecoration(
        color: scheme.primary,
        image: const DecorationImage(
          image: NetworkImage(
            'https://www.transparenttextures.com/patterns/cubes.png',
          ),
          repeat: ImageRepeat.repeat,
          opacity: 0.05,
        ),
      ),
    );
  }

  Widget _buildUpdateAvailableBanner({
    required ColorScheme scheme,
    required String? latestVersion,
    required VoidCallback onUpdate,
    required VoidCallback onDismiss,
  }) {
    return Material(
      elevation: 3,
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                latestVersion != null
                    ? '새 버전 v$latestVersion 사용 가능 (현재 v$kAppVersion)'
                    : '새 버전 사용 가능 (현재 v$kAppVersion)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
            TextButton(onPressed: onUpdate, child: const Text('업데이트')),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onDismiss,
              tooltip: '닫기',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoUpdateChip({
    required String? latestVersion,
    required bool forceUpdate,
    required VoidCallback onTap,
  }) {
    final bg = forceUpdate
        ? Colors.red.shade700.withValues(alpha: 0.92)
        : Colors.amber.shade700.withValues(alpha: 0.92);
    final border = forceUpdate
        ? Colors.red.shade200.withValues(alpha: 0.85)
        : Colors.amber.shade200.withValues(alpha: 0.85);
    final label = forceUpdate
        ? '업데이트 필요'
        : (latestVersion != null ? 'v$latestVersion' : '업데이트');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Tooltip(
          message: forceUpdate
              ? '필수 업데이트: ${latestVersion ?? '최신'} 설치'
              : latestVersion != null
              ? '새 버전 v$latestVersion · 탭하여 업데이트'
              : '새 버전 · 탭하여 업데이트',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.98),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          child: const Icon(
            Icons.door_front_door_rounded,
            size: 14,
            color: Colors.white,
          ),
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
}

class _IssuanceNavIcon extends StatelessWidget {
  const _IssuanceNavIcon({
    required this.badgeAsync,
    this.selected = false,
    this.selectedColor,
  });

  final AsyncValue<int> badgeAsync;
  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
      color: selected ? selectedColor : null,
    );
    final count = badgeAsync.valueOrNull ?? 0;
    if (count <= 0) return icon;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: icon);
  }
}

class _MainBottomNavBar extends StatelessWidget {
  const _MainBottomNavBar({
    required this.selectedIndex,
    required this.issuanceBadgeAsync,
    required this.onTapHome,
    required this.onLongPressHome,
    required this.onTapReception,
    required this.onLongPressReception,
    required this.onTapIssuance,
    required this.onTapMenu,
  });

  final int selectedIndex;
  final AsyncValue<int> issuanceBadgeAsync;
  final VoidCallback onTapHome;
  final VoidCallback onLongPressHome;
  final VoidCallback onTapReception;
  final VoidCallback onLongPressReception;
  final VoidCallback onTapIssuance;
  final VoidCallback onTapMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homeAccent = scheme.primary;
    final receptionAccent = scheme.tertiary;
    final issuanceAccent = Colors.teal.shade700;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                label: '홈',
                selected: selectedIndex == 0,
                selectedIcon: Icons.home_rounded,
                unselectedIcon: Icons.home_outlined,
                accentColor: homeAccent,
                onTap: onTapHome,
                onLongPress: onLongPressHome,
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                label: '접수',
                selected: selectedIndex == 1,
                selectedIcon: Icons.add_ic_call_rounded,
                unselectedIcon: Icons.add_ic_call_rounded,
                accentColor: receptionAccent,
                onTap: onTapReception,
                onLongPress: onLongPressReception,
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                label: '발급',
                selected: selectedIndex == 2,
                customIcon: _IssuanceNavIcon(
                  badgeAsync: issuanceBadgeAsync,
                  selected: selectedIndex == 2,
                  selectedColor: issuanceAccent,
                ),
                accentColor: issuanceAccent,
                onTap: onTapIssuance,
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                label: '메뉴',
                selected: selectedIndex == 3,
                selectedIcon: Icons.menu_rounded,
                unselectedIcon: Icons.menu_open_rounded,
                accentColor: scheme.secondary,
                onTap: onTapMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.selectedIcon,
    this.unselectedIcon,
    this.customIcon,
    this.accentColor,
    this.tag,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? selectedIcon;
  final IconData? unselectedIcon;
  final Widget? customIcon;
  final Color? accentColor;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? (accentColor ?? scheme.primary)
        : scheme.onSurfaceVariant.withValues(alpha: 0.9);
    final bg = selected
        ? (accentColor ?? scheme.primary).withValues(alpha: 0.22)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 2,
                width: selected ? 18 : 0,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              customIcon ??
                  Icon(
                    selected ? selectedIcon : unselectedIcon,
                    color: fg,
                    size: selected ? 24 : 22,
                  ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: fg,
                  height: 1.1,
                ),
              ),
              if (tag != null) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: scheme.onTertiaryContainer,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
