import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/ux_onboarding_sheet.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_providers.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_screen.dart';
import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_theme.dart';
import 'package:coad_customer_calls/features/quoter/quoter_hub_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_providers.dart';
import 'package:coad_customer_calls/features/quoter/shutter_estimator_log_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_search_delegate.dart';
import 'package:coad_customer_calls/features/settings/app_usage_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/theme/app_motion.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:coad_customer_calls/navigation/app_menu.dart';
import 'package:coad_customer_calls/navigation/app_menu_drawer.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/providers/app_update_provider.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
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
  // IndexedStack 본문 탭 (접수·더보기는 네비 전용)
  static const int _homeTabIndex = 0;
  static const int _issuanceTabIndex = 1;
  static const int _quoterTabIndex = 2;
  static const int _generalScheduleTabIndex = 3;

  // 하단 네비: 홈 · 접수 · 발급 · 견적 · (본사일반) · 더보기
  static const int _navHomeIndex = 0;
  static const int _navReceptionIndex = 1;
  static const int _navIssuanceIndex = 2;
  static const int _navQuoterIndex = 3;
  static const int _navGeneralScheduleIndex = 4;
  int _currentIndex = 0;
  int _navSelectedIndex = _navHomeIndex;
  final Set<int> _loadedIndices = {0}; // 초기에 로드할 인덱스 (홈)
  /// 홈에서 연속 뒤로가기 시 앱 종료(스낵바 안내 후 2초 이내 재입력)
  DateTime? _lastBackExitHintAt;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        unawaited(showUxOnboardingIfNeeded(context, ref));
      });
    });

    // 흐름 프리페치 후 여유 있을 때 처리할 미통화·발급 감시 (첫 화면 네트워크 혼잡 완화)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        unawaited(ref.read(hubPendingUncalledSummaryProvider.future));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _startIssuanceCompletionWatcher();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        ref.read(issuanceBadgeLoadEnabledProvider.notifier).state = true;
      });
    });

    // 유휴 시 견적 단가 프리페치 — 견적 탭 첫 진입 체감 단축
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        unawaited(ref.read(shutterPricesFutureProvider.future));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(refreshPendingSyncCount(ref, autoSync: true));
    });

    // 2. Sync FCM token with Supabase for the current user
    final user = ref.read(authControllerProvider);
    if (user != null) {
      unawaited(NotificationService.updateTokenInSupabase(user.id));
      NotificationService.listenToTokenRefresh(user.id);
      _trackAppOpen(user);
    }
  }

  void _trackAppOpen(AppUser user) {
    unawaited(UsageService.recordAppOpen(userId: user.id, userName: user.name));
  }

  void _trackTab(AppUser? user, String tabKey) {
    if (user == null) return;
    unawaited(
      UsageService.recordTab(
        userId: user.id,
        userName: user.name,
        tabKey: tabKey,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService.onAppResumed());
      final user = ref.read(authControllerProvider);
      if (user != null) {
        unawaited(NotificationService.updateTokenInSupabase(user.id));
        _trackAppOpen(user);
      }
      unawaited(refreshPendingSyncCount(ref, autoSync: true));
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
    // 연속 DB 이벤트 배치 — 500ms보다 길게 잡아 전체 refetch 폭주 완화.
    _issuanceCompletionDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      unawaited(_runIssuanceWatchCheck());
    });
  }

  Future<void> _runIssuanceWatchCheck() async {
    final onIssuanceTab = _currentIndex == _issuanceTabIndex;
    if (onIssuanceTab) {
      // 발급 탭: 캐시 무효화만 — 구독 중 위젯이 한 번 재조회. 강제 이중 fetch 없음.
      invalidateIssuanceCore(ref);
      await _checkIssuanceCompletionAndNotify();
      await _checkIssuanceRequestAndNotify();
    } else {
      // 다른 탭: 경량 배지만. 전체 목록 refetch·로컬 알림 스캔은 생략
      // (원격 푸시/FCM이 알림 담당, 배지로 건수 반영).
      invalidateIssuanceBadgeOnly(ref);
    }
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
      final isAdmin = isAppAdmin(user);

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
    _trackTab(ref.read(authControllerProvider), 'home');
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
    _trackTab(ref.read(authControllerProvider), 'issuance');
  }

  void _selectQuoterTab() {
    HapticFeedback.selectionClick();
    _loadedIndices.add(_quoterTabIndex);
    if (_navSelectedIndex == _navQuoterIndex &&
        _currentIndex == _quoterTabIndex) {
      return;
    }
    setState(() {
      _navSelectedIndex = _navQuoterIndex;
      _currentIndex = _quoterTabIndex;
      _loadedIndices.add(_quoterTabIndex);
      _lastBackExitHintAt = null;
    });
    _trackTab(ref.read(authControllerProvider), 'quoter');
  }

  bool _showGeneralScheduleInNav(AppUser? user) =>
      user != null && canAccessGeneralSchedule(user);

  /// 홈(0) 접수(1) 발급(2) 견적(3) [본사일반(4)] 더보기
  int _navMenuIndexFor(AppUser? user) =>
      _showGeneralScheduleInNav(user) ? 5 : 4;

  void _syncNavFromCurrentTab() {
    final user = ref.read(authControllerProvider);
    setState(() {
      _navSelectedIndex = switch (_currentIndex) {
        _issuanceTabIndex => _navIssuanceIndex,
        _quoterTabIndex => _navQuoterIndex,
        _generalScheduleTabIndex =>
          _showGeneralScheduleInNav(user)
              ? _navGeneralScheduleIndex
              : _navHomeIndex,
        _ => _navHomeIndex,
      };
      if (_navSelectedIndex == _navGeneralScheduleIndex &&
          !_showGeneralScheduleInNav(user)) {
        _navSelectedIndex = _navHomeIndex;
        if (_currentIndex == _generalScheduleTabIndex) {
          _currentIndex = _homeTabIndex;
        }
      }
    });
  }

  void _openMenuDrawer() {
    HapticFeedback.lightImpact();
    final user = ref.read(authControllerProvider);
    _trackTab(user, 'menu');
    setState(() => _navSelectedIndex = _navMenuIndexFor(user));
    ref.read(mainScaffoldKeyProvider).currentState?.openDrawer();
  }

  void _selectGeneralScheduleTab() {
    final user = ref.read(authControllerProvider);
    if (!_showGeneralScheduleInNav(user)) {
      _selectHomeTab();
      return;
    }
    HapticFeedback.lightImpact();
    if (_navSelectedIndex == _navGeneralScheduleIndex &&
        _currentIndex == _generalScheduleTabIndex) {
      return;
    }
    setState(() {
      _navSelectedIndex = _navGeneralScheduleIndex;
      _currentIndex = _generalScheduleTabIndex;
      _loadedIndices.add(_generalScheduleTabIndex);
      _lastBackExitHintAt = null;
    });
    _trackTab(user, 'general_schedule');
  }

  void _onNavDestinationSelected(int navIndex) {
    final user = ref.read(authControllerProvider);
    final menuIndex = _navMenuIndexFor(user);
    if (navIndex == menuIndex) {
      _openMenuDrawer();
      return;
    }
    if (_showGeneralScheduleInNav(user) &&
        navIndex == _navGeneralScheduleIndex) {
      _selectGeneralScheduleTab();
      return;
    }
    if (navIndex == _navQuoterIndex) {
      _selectQuoterTab();
      return;
    }
    if (navIndex == _navReceptionIndex) {
      // 탭 = 새 접수(현장 1차 액션). 목록은 롱프레스 퀵메뉴.
      _trackTab(user, 'reception');
      unawaited(_openReceptionCreate());
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
      AppMotion.fadeSlideRoute<void>(
        settings: const RouteSettings(name: kSalesCallCreateRouteName),
        builder: (_) => const SalesCallCreateScreen(),
      ),
    );
  }

  /// 접수 롱프레스 — 목록 바로가기(탭은 등록으로 직행).
  Future<void> _openReceptionQuickActions() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // 기본 half-sheet 제약이 타이트해 Column overflow가 나기 쉬움 →
      // 콘텐츠 높이만큼만 쓰고, 넘치면 스크롤.
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '접수 바로가기',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '탭: 새 접수 · 길게: 이 메뉴',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('create'),
                  icon: const Icon(Icons.add_ic_call_rounded),
                  label: const Text('새 접수 등록'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppTokens.primaryCtaHeight),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minVerticalPadding: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(Icons.list_alt_rounded, color: scheme.primary),
                  title: const Text(
                    '오늘 접수 목록',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('금일 접수 건 조회'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop('today'),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  minVerticalPadding: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    Icons.phone_missed_rounded,
                    color: scheme.error,
                  ),
                  title: const Text(
                    '오늘 미통화 목록',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('금일 미통화 건 조회'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop('incomplete'),
                ),
              ],
            ),
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

  Future<void> _openPendingUncalledList() async {
    final today = todayYmdSeoul();
    final loginName = ref.read(authControllerProvider)?.name?.trim();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.pendingUncalled,
          date: pendingUncalledFromYmd(today),
          initialAssignee: loginName != null && loginName.isNotEmpty
              ? loginName
              : null,
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
        : const AppLoading(message: '발급 화면 준비 중…'),
    _loadedIndices.contains(_quoterTabIndex)
        ? const QuoterHubScreen(showAppBar: true)
        : const AppLoading(message: '견적 화면 준비 중…'),
    _loadedIndices.contains(_generalScheduleTabIndex)
        ? const GeneralScheduleScreen(embedded: true)
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
    ref.listen(pendingGeneralScheduleLaunchProvider, (prev, next) {
      if (next != true || !context.mounted) return;
      ref.read(pendingGeneralScheduleLaunchProvider.notifier).state = false;
      NotificationService.clearPendingGeneralScheduleNavigation();
      _selectGeneralScheduleTab();
    });
    ref.listen(pendingQuoterLaunchProvider, (prev, next) {
      if (next != true || !context.mounted) return;
      ref.read(pendingQuoterLaunchProvider.notifier).state = false;
      _selectQuoterTab();
    });

    final scheme = Theme.of(context).colorScheme;
    final tabAccent = scheme.primary;
    final appBarBg = Color.lerp(
      scheme.primary,
      Colors.black,
      scheme.brightness == Brightness.dark ? 0.28 : 0.12,
    )!;
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);
    final showGeneralSchedule = ref.watch(
      authControllerProvider.select(
        (u) => u != null && canAccessGeneralSchedule(u),
      ),
    );
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
          if (!isOpen) {
            final user = ref.read(authControllerProvider);
            if (_navSelectedIndex == _navMenuIndexFor(user)) {
              _syncNavFromCurrentTab();
            }
          }
        },
        drawer: Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(authControllerProvider);
            final updateStatus = ref.watch(appUpdateStatusProvider).valueOrNull;
            return _buildAppMenuDrawer(context, user, scheme, updateStatus);
          },
        ),
        // 본사일반·견적은 자체 AppBar를 쓰므로 메인 AppBar를 숨긴다.
        appBar: (_currentIndex == _generalScheduleTabIndex ||
                _currentIndex == _quoterTabIndex)
            ? null
            : AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openHomeFlowToday,
                      child: _buildBrandTitle(),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final updateStatus = ref
                            .watch(appUpdateStatusProvider)
                            .valueOrNull;
                        if (updateStatus?.hasUpdate != true) {
                          return const SizedBox.shrink();
                        }
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            _buildLogoUpdateChip(
                              latestVersion: updateStatus?.latestVersion,
                              forceUpdate: updateStatus?.forceUpdate == true,
                              onTap: () =>
                                  AppUpdateService.checkAndUpdateIfNeeded(
                                    context,
                                    forceRecheck: true,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                centerTitle: true,
                backgroundColor: appBarBg,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final repository = ref.read(salesCallsRepositoryProvider);
                      final calls =
                          ref.read(todayCallsContentProvider).value ?? [];
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
                    duration: AppTokens.fast,
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
        // 업데이트 안내는 AppBar 칩 단일 진입점.
        // 오프라인 대기는 전 탭 공통 상단 배너.
        body: Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final pending = ref.watch(pendingSyncCountProvider);
                if (pending <= 0) return const SizedBox.shrink();
                return _PendingSyncBanner(
                  count: pending,
                  onSync: () async {
                    final result = await refreshPendingSyncCount(
                      ref,
                      autoSync: true,
                    );
                    if (!context.mounted) return;
                    if (result.synced > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('미전송 ${result.synced}건이 동기화되었습니다.'),
                        ),
                      );
                    } else if (result.count > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('아직 전송되지 않은 항목이 있습니다. 네트워크를 확인해 주세요.'),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  final screens = _buildScreens();
                  // 비활성 탭 애니메이션 정지 + 리페인트 분리 → 탭 전환·스크롤 체감 개선
                  return IndexedStack(
                    index: _currentIndex,
                    children: [
                      for (var i = 0; i < screens.length; i++)
                        TickerMode(
                          enabled: i == _currentIndex,
                          child: RepaintBoundary(child: screens[i]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: Consumer(
          builder: (context, ref, _) => RepaintBoundary(
            child: _MainBottomNavBar(
              selectedIndex: _navSelectedIndex,
              showGeneralSchedule: showGeneralSchedule,
              issuanceBadgeAsync: ref.watch(
                issuanceRequestBadgeCountVisibleProvider,
              ),
              onTapHome: () => _onNavDestinationSelected(_navHomeIndex),
              onLongPressHome: _openHomeFlowToday,
              onTapReception: () =>
                  _onNavDestinationSelected(_navReceptionIndex),
              onLongPressReception: _openReceptionQuickActions,
              onTapIssuance: () => _onNavDestinationSelected(_navIssuanceIndex),
              onTapQuoter: () => _onNavDestinationSelected(_navQuoterIndex),
              onTapGeneralSchedule: () =>
                  _onNavDestinationSelected(_navGeneralScheduleIndex),
              onTapMenu: () => _onNavDestinationSelected(
                _navMenuIndexFor(ref.read(authControllerProvider)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppMenuCatalog _buildMenuCatalog(
    BuildContext context,
    AppUpdateStatus? updateStatus,
    AppUser? user,
  ) {
    // 드로어 context로 닫은 뒤, 호스트(메인) context로 push 해야 unmounted 오류가 없다.
    final hostContext = this.context;
    void closeDrawerThen(VoidCallback action) {
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        action();
      });
    }

    return AppMenuCatalog(
      sections: const [
        AppMenuSection(id: 'tools', title: '업무 도구'),
        AppMenuSection(id: 'shortcuts', title: '바로가기'),
        AppMenuSection(id: 'account', title: '계정'),
      ],
      entries: [
        AppMenuEntry(
          id: 'shutter_quoter',
          sectionId: 'tools',
          icon: Icons.calculate_rounded,
          title: '셔터 견적기',
          subtitle: 'COAD_home과 동일 계산 · 견적서 작성',
          quickAccess: true,
          quickLabel: '견적',
          keywords: const [
            '견적',
            '셔터',
            '견적기',
            'estimator',
            '단가',
            '모터',
            '슬라트',
          ],
          onTap: () => closeDrawerThen(_selectQuoterTab),
        ),
        AppMenuEntry(
          id: 'home_pending_uncalled',
          sectionId: 'shortcuts',
          icon: Icons.phone_missed_rounded,
          title: '처리할 미통화',
          quickAccess: true,
          quickLabel: '미통화',
          keywords: const ['미통화', '미결', '콜', '홈', '처리'],
          onTap: () => closeDrawerThen(() {
            _selectHomeTab();
            unawaited(_openPendingUncalledList());
          }),
        ),
        AppMenuEntry(
          id: 'home_calendar',
          sectionId: 'shortcuts',
          icon: Icons.calendar_month_rounded,
          title: '상담 달력',
          quickAccess: true,
          quickLabel: '달력',
          keywords: const ['달력', '일정', '팔로우', '오늘'],
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
          id: 'reception_today',
          sectionId: 'shortcuts',
          icon: Icons.list_alt_rounded,
          title: '오늘 접수 목록',
          quickAccess: true,
          quickLabel: '오늘 접수',
          keywords: const ['목록', '오늘', '접수', '금일'],
          onTap: () =>
              closeDrawerThen(() => unawaited(_openTodayReceptionList())),
        ),
        AppMenuEntry(
          id: 'reception_incomplete_today',
          sectionId: 'shortcuts',
          icon: Icons.phone_callback_rounded,
          title: '오늘 미통화 목록',
          quickAccess: true,
          quickLabel: '오늘 미통화',
          keywords: const ['미통화', '목록', '금일'],
          onTap: () =>
              closeDrawerThen(() => unawaited(_openTodayIncompleteList())),
        ),
        AppMenuEntry(
          id: 'search',
          sectionId: 'shortcuts',
          icon: Icons.search_rounded,
          title: '통합 검색',
          quickAccess: true,
          quickLabel: '검색',
          keywords: const ['검색', '고객', '찾기'],
          onTap: () => closeDrawerThen(() {
            final repository = ref.read(salesCallsRepositoryProvider);
            final calls = ref.read(todayCallsContentProvider).value ?? [];
            showSearch(
              context: hostContext,
              delegate: SalesCallSearchDelegate(
                initialItems: calls,
                repository: repository,
              ),
            );
          }),
        ),
        if (isAppAdmin(user))
          AppMenuEntry(
            id: 'app_usage',
            sectionId: 'account',
            icon: Icons.bar_chart_rounded,
            title: '앱 사용량',
            subtitle: '앱 사용 기록이 있는 직원 통계',
            quickAccess: true,
            quickLabel: '사용량',
            keywords: const ['사용량', '통계', '관리'],
            onTap: () => closeDrawerThen(() {
              Navigator.of(hostContext).push(
                MaterialPageRoute<void>(builder: (_) => const AppUsageScreen()),
              );
            }),
          ),
        if (isAppAdmin(user))
          AppMenuEntry(
            id: 'shutter_estimator_log',
            sectionId: 'account',
            icon: Icons.history_edu_rounded,
            title: '견적기 사용 이력',
            subtitle: '셔터 견적기 사용 통계 (COAD_home 동일)',
            quickAccess: true,
            quickLabel: '견적이력',
            keywords: const ['견적', '이력', '통계', '관리', '셔터'],
            onTap: () => closeDrawerThen(() {
              _trackTab(user, 'quoter_log');
              Navigator.of(hostContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShutterEstimatorLogScreen(),
                ),
              );
            }),
          ),
        AppMenuEntry(
          id: 'settings',
          sectionId: 'account',
          icon: Icons.settings_outlined,
          title: '설정',
          quickAccess: true,
          quickLabel: '설정',
          badge: updateStatus?.hasUpdate == true ? '업데이트' : null,
          keywords: const ['환경', '업데이트', '미통화 안내'],
          onTap: () => closeDrawerThen(() {
            _trackTab(user, 'settings');
            Navigator.of(hostContext).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          }),
        ),
        AppMenuEntry(
          id: 'logout',
          sectionId: 'account',
          icon: Icons.logout,
          title: '로그아웃',
          quickAccess: true,
          quickLabel: '로그아웃',
          keywords: const ['로그아웃', '종료'],
          onTap: () {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              final confirm = await showDialog<bool>(
                context: hostContext,
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
              if (confirm == true && mounted) {
                await ref.read(authControllerProvider.notifier).logout();
              }
            });
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
      catalog: _buildMenuCatalog(context, updateStatus, user),
      accountName: '${user?.name ?? '사용자'} 님',
      accountSubtitle: '사번/ID: ${user?.id ?? '-'}',
      headerDecoration: BoxDecoration(
        color: scheme.primary,
        // 외부 텍스처 URL 제거 — 오프라인·지연 방지, 단색 + 은은한 그라데이션.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.primaryContainer, 0.35)!,
          ],
        ),
      ),
    );
  }

  /// 업데이트 단일 진입점 — AppBar 칩 (필수·선택 공통).
  Widget _buildLogoUpdateChip({
    required String? latestVersion,
    required bool forceUpdate,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = forceUpdate
        ? AppTokens.updateForceBg(scheme)
        : AppTokens.updateOptionalBg(scheme);
    final fg = forceUpdate
        ? AppTokens.updateForceFg(scheme)
        : AppTokens.updateOptionalFg(scheme);
    final border = forceUpdate
        ? scheme.onError.withValues(alpha: 0.35)
        : scheme.onPrimary.withValues(alpha: 0.35);
    final label = forceUpdate
        ? '업데이트 필요'
        : (latestVersion != null ? 'v$latestVersion' : '업데이트');

    return Semantics(
      button: true,
      label: forceUpdate
          ? '필수 업데이트 ${latestVersion ?? ''}'
          : '새 버전 ${latestVersion ?? ''} 업데이트',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
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
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update_alt_rounded, size: 14, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg,
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
            Icons.phone_in_talk_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'COAD 영업',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// 전 탭 공통 — 오프라인 접수·상담 대기 건수.
class _PendingSyncBanner extends StatelessWidget {
  const _PendingSyncBanner({required this.count, required this.onSync});

  final int count;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '전송 대기 $count건 · 연결되면 자동 또는 수동 전송',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onSync,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('지금 전송'),
              ),
            ],
          ),
        ),
      ),
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
    required this.showGeneralSchedule,
    required this.issuanceBadgeAsync,
    required this.onTapHome,
    required this.onLongPressHome,
    required this.onTapReception,
    required this.onLongPressReception,
    required this.onTapIssuance,
    required this.onTapQuoter,
    required this.onTapGeneralSchedule,
    required this.onTapMenu,
  });

  final int selectedIndex;
  final bool showGeneralSchedule;
  final AsyncValue<int> issuanceBadgeAsync;
  final VoidCallback onTapHome;
  final VoidCallback onLongPressHome;
  final VoidCallback onTapReception;
  final VoidCallback onLongPressReception;
  final VoidCallback onTapIssuance;
  final VoidCallback onTapQuoter;
  final VoidCallback onTapGeneralSchedule;
  final VoidCallback onTapMenu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final homeAccent = scheme.primary;
    final receptionAccent = AppTokens.receptionAccent(scheme);
    final issuanceAccent = IssuanceVisual.navAccent(scheme);
    // 견적 탭 — 접수 다음으로 눈에 띄는 틸/그린 톤
    final quoterAccent = Color.lerp(
      const Color(0xFF0D9488),
      scheme.primary,
      0.15,
    )!;
    final generalScheduleAccent = AppTokens.generalScheduleAccent(scheme);
    // 홈0 접수1 발급2 견적3 [본사4] 더보기4or5
    final menuIndex = showGeneralSchedule ? 5 : 4;
    final gsIndex = 4;
    final quoterSelected = selectedIndex == 3;
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
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
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
            // 테슬라 컨트롤식 프라이머리 CTA — 새 접수를 가장 크게
            Expanded(
              child: _ReceptionPrimaryNavItem(
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
              child: _QuoterNavItem(
                selected: quoterSelected,
                accentColor: quoterAccent,
                onTap: onTapQuoter,
              ),
            ),
            if (showGeneralSchedule)
              Expanded(
                child: _BottomNavItem(
                  label: '본사일반',
                  tag: kGeneralScheduleTestLabel.isEmpty
                      ? null
                      : kGeneralScheduleTestLabel,
                  selected: selectedIndex == gsIndex,
                  selectedIcon: Icons.engineering_rounded,
                  unselectedIcon: Icons.engineering_outlined,
                  accentColor: generalScheduleAccent,
                  onTap: onTapGeneralSchedule,
                ),
              ),
            Expanded(
              child: _BottomNavItem(
                label: '더보기',
                selected: selectedIndex == menuIndex,
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

/// 하단 견적 탭 — 아이콘 칩으로 한눈에 구분.
class _QuoterNavItem extends StatelessWidget {
  const _QuoterNavItem({
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '견적',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 44 : 40,
                  height: selected ? 36 : 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor
                        : accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.calculate_rounded,
                    size: selected ? 22 : 20,
                    color: selected ? scheme.onPrimary : accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '견적',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected
                        ? accentColor
                        : scheme.onSurfaceVariant.withValues(alpha: 0.95),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 네비 중앙 프라이머리 — 큰 터치·즉시 등록.
class _ReceptionPrimaryNavItem extends StatelessWidget {
  const _ReceptionPrimaryNavItem({
    required this.accentColor,
    required this.onTap,
    required this.onLongPress,
  });

  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '접수',
      hint: '짧게 누르면 새 접수, 길게 누르면 오늘 목록 메뉴',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_ic_call_rounded,
                    color: scheme.onPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '접수',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
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

    final semanticsHint = onLongPress == null
        ? null
        : (label == '접수' ? '길게 누르면 오늘 목록 메뉴' : '길게 누르면 추가 동작');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: semanticsHint,
      child: Material(
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
            constraints: const BoxConstraints(
              minHeight: AppTokens.minTouchTarget,
            ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: fg,
                        height: 1.1,
                      ),
                    ),
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
      ),
    );
  }
}
