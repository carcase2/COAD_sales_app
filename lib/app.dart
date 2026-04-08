import 'package:coad_customer_calls/features/auth/login_screen.dart';
import 'package:coad_customer_calls/features/main/main_tab_screen.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
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
      title: '코아드 고객전화',
      navigatorKey: NotificationService.navigatorKey,
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      ),
      home: user == null ? const LoginScreen() : const MainTabScreen(),
    );
  }
}
