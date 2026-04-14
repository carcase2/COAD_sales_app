import 'package:coad_customer_calls/features/home/home_hub_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/home/home_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
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

    return Scaffold(
      extendBody: true, // 하단 바가 배경을 가리지 않도록 (플로팅 효과)
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
}
