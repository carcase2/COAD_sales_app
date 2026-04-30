import 'package:coad_customer_calls/features/auth/login_screen.dart';
import 'package:coad_customer_calls/features/main/main_tab_screen.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:coad_customer_calls/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoadCustomerCallsApp extends ConsumerWidget {
  const CoadCustomerCallsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'COAD 영업',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clampedScale = media.textScaler.clamp(
          minScaleFactor: 0.95,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clampedScale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: user == null ? const LoginScreen() : const MainTabScreen(),
    );
  }
}
