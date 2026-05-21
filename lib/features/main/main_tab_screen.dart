import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_search_delegate.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedIndices = {0}; // 초기에 로드할 인덱스 (홈)
  /// 홈에서 연속 뒤로가기 시 앱 종료(스낵바 안내 후 2초 이내 재입력)
  DateTime? _lastBackExitHintAt;
  RealtimeChannel? _issuanceCompletionWatchChannel;
  Timer? _issuanceCompletionDebounce;

  @override
  void initState() {
    super.initState();
    // 1. Handle deep link if app was opened via notification (Cold Start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.handleInitialMessage();
      AppUpdateService.checkAndUpdateIfNeeded(context);
    });

    // 홈(미통화·달력)이 쓰는 대량 목록을 백그라운드로 미리 불러 전환 시 빨리 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(rankingCallsProvider.future));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startIssuanceCompletionWatcher();
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
    _issuanceCompletionWatchChannel?.unsubscribe();
    _issuanceCompletionWatchChannel = Supabase.instance.client
        .channel('issuance-completion-watch')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tax_invoice_issues',
          callback: (_) => _scheduleIssuanceCompletionCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tax_invoice_issues',
          callback: (_) => _scheduleIssuanceCompletionCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'performance_bond_issues',
          callback: (_) => _scheduleIssuanceCompletionCheck(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'performance_bond_issues',
          callback: (_) => _scheduleIssuanceCompletionCheck(),
        )
        .subscribe();
  }

  void _scheduleIssuanceCompletionCheck() {
    _issuanceCompletionDebounce?.cancel();
    _issuanceCompletionDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
      ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
      unawaited(_checkIssuanceCompletionAndNotify());
    });
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

      for (final row in allCompleted) {
        final key = rowKey(row);
        if (!newKeys.contains(key)) continue;
        final isTax = row.domain == IssuanceDomain.taxInvoice;
        final title = isTax ? '세금계산서 발급 완료' : '이행증권 발급 완료';
        final name = isTax
            ? (row.master['customer_name'] ?? '요청 건').toString()
            : (row.master['company_name'] ?? row.master['site_name'] ?? '요청 건')
                  .toString();
        await NotificationService.showIssuanceCompletedAlert(
          title: title,
          body: '$name 건이 발급 완료되었습니다.',
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

  void _onTabSelected(int index) {
    if (index == 0) {
      ref.read(homeHubFlowResetTickProvider.notifier).state++;
    }
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
      _loadedIndices.add(index); // 선택한 탭을 로드 목록에 추가
      if (index != 0) _lastBackExitHintAt = null;
    });
  }

  Future<void> _openReceptionCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SalesCallCreateScreen(),
      ),
    );
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

  List<Widget> _buildScreens() => [const HomeHubScreen()];

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingConsultationLaunchProvider, (prev, next) {
      if (next == null) return;
      _onTabSelected(0);
    });
    ref.listen(pendingIssuanceLaunchProvider, (prev, next) {
      if (next == null || !context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const IssuanceRequestScreen(),
        ),
      );
    });

    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider);
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);
    final actionsBottom = 12.0 + MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        final sm = scaffoldKey.currentState;
        if (sm != null && sm.isDrawerOpen) {
          sm.closeDrawer();
          return;
        }

        if (_currentIndex != 0) {
          ref.read(homeHubFlowResetTickProvider.notifier).state++;
          setState(() => _currentIndex = 0);
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
        drawer: _buildDrawer(context, user, scheme),
        appBar: AppBar(
          title: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onTabSelected(0),
            child: _buildBrandTitle(),
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
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'v$kAppVersion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
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
        ),
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _buildScreens()),
            Positioned(
              right: 16,
              bottom: actionsBottom,
              child: FloatingActionButton.extended(
                heroTag: 'global_call_create',
                backgroundColor: scheme.tertiary,
                foregroundColor: scheme.onTertiary,
                onPressed: _openReceptionCreate,
                tooltip: '접수 등록',
                icon: const Icon(Icons.add_ic_call_rounded),
                label: const Text(
                  '접수',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
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
              child: Icon(
                Icons.person,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            accountName: Text(
              '${user?.name ?? '사용자'} 님',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              '사번/ID: ${user?.id ?? '-'}',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8)),
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              image: const DecorationImage(
                image: NetworkImage(
                  'https://www.transparenttextures.com/patterns/cubes.png',
                ),
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
              requestHomeHubSection(ref, HomeHubSection.flow);
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
            scheme: scheme,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Text(
              'COAD Sales App v$kAppVersion',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
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
    String? menuBadge,
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
      trailing: menuBadge == null
          ? null
          : Text(
              menuBadge,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
