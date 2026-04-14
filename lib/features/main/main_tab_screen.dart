import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/home/home_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/features/settings/settings_screen.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _currentIndex = 0;
  final Set<int> _loadedIndices = {0}; // 초기에 로드할 인덱스 (홈)

  @override
  void initState() {
    super.initState();
    // 1. Handle deep link if app was opened via notification (Cold Start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.handleInitialMessage();
    });

    // 2. Sync FCM token with Supabase for the current user
    final user = ref.read(authControllerProvider);
    if (user != null) {
      NotificationService.updateTokenInSupabase(user.id);
      NotificationService.listenToTokenRefresh(user.id);
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
      _loadedIndices.add(index); // 선택한 탭을 로드 목록에 추가
    });
  }

  List<Widget> _buildScreens() {
    return [
      HomeHubScreen(onNavigateToTab: _onTabSelected),
      _loadedIndices.contains(1) ? const ConsultationStatusScreen() : const SizedBox.shrink(),
      _loadedIndices.contains(2) ? const QuoterScreen() : const SizedBox.shrink(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isVisible = ref.watch(bottomBarVisibilityProvider);
    final user = ref.watch(authControllerProvider);
    final scaffoldKey = ref.watch(mainScaffoldKeyProvider);

    return Scaffold(
      key: scaffoldKey,
      extendBody: true,
      drawer: _buildDrawer(context, user, scheme),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'COAD Hub' : (_currentIndex == 1 ? '상담현황' : '견적기'),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              final repository = ref.read(salesCallsRepositoryProvider);
              // 현재 상황에 맞는 초기 데이터를 넘겨줄 수도 있지만, 
              // 전역 검색이므로 빈 목록이나 오늘 목록을 유연하게 넘김
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
      body: IndexedStack(
        index: _currentIndex,
        children: _buildScreens(),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 1.5),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.transparent,
              height: 65,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  );
                }
                return TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant.withOpacity(0.7),
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              surfaceTintColor: Colors.transparent,
              onDestinationSelected: _onTabSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment_rounded),
                  label: '상담현황',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calculate_outlined),
                  selectedIcon: Icon(Icons.calculate_rounded),
                  label: '견적기',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AppUser? user, ColorScheme scheme) {
    return Drawer(
      child: Column(
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
          
          _buildDrawerSectionTitle('상담 관리', scheme),
          _buildDrawerItem(
            icon: Icons.pending_actions_rounded,
            title: '미통화 상담 내역',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SalesCallListScreen(mode: ListQueryMode.incomplete),
              ));
            },
            scheme: scheme,
          ),
          _buildDrawerItem(
            icon: Icons.history_rounded,
            title: '최근 등록 현황',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SalesCallListScreen(mode: ListQueryMode.recent),
              ));
            },
            scheme: scheme,
          ),
          _buildDrawerItem(
            icon: Icons.list_alt_rounded,
            title: '전체 상담 목록',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SalesCallListScreen(mode: ListQueryMode.recent), // 전체도 최근순으로 보기
              ));
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
          
          const Spacer(),
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
            padding: const EdgeInsets.only(bottom: 24), // 충분한 하단 여백 부여 (탭바 간섭 방지)
            child: Text(
              'COAD Sales App v$kAppVersion',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withOpacity(0.5)),
            ),
          ),
        ],
      ),
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
