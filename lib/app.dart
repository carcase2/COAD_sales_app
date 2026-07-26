import 'package:coad_customer_calls/features/auth/login_screen.dart';
import 'package:coad_customer_calls/features/main/main_tab_screen.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:coad_customer_calls/theme/app_motion.dart';
import 'package:coad_customer_calls/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/providers/theme_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoadCustomerCallsApp extends ConsumerWidget {
  const CoadCustomerCallsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'COAD 영업',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clampedScale = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.4,
        );
        // 전역 스크롤·텍스트 스케일 + 부드러운 터치 피드백
        return MediaQuery(
          data: media.copyWith(textScaler: clampedScale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(
      authControllerProvider.select((user) => user != null),
    );
    return loggedIn ? const MainTabScreen() : const LoginScreen();
  }
}
