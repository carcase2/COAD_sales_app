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

  final List<Widget> _screens = const [
    HomeScreen(),
    QuoterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          surfaceTintColor: Colors.transparent,
          backgroundColor: scheme.surface,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.phone_outlined),
              selectedIcon: Icon(Icons.phone_rounded),
              label: '고객전화',
            ),
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate_rounded),
              label: '견적기',
            ),
          ],
        ),
      ),
    );
  }
}
