import 'package:coad_customer_calls/app.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/core/network/sales_api_transport.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:coad_customer_calls/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 병렬 초기화 (상호 의존성 없는 작업들 먼저 수행)
  final results = await Future.wait([
    Firebase.initializeApp(),
    initializeDateFormatting('ko_KR', null),
    dotenv.load(fileName: ".env"),
    SharedPreferences.getInstance(),
  ]);

  final prefs = results[3] as SharedPreferences;

  // 타임존 설정 (비동기 아님)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  // 2. 의존성 있는 작업 병렬 수행 (Firebase와 dotenv가 준비된 후)
  await Future.wait([
    NotificationService.init(),
    Supabase.initialize(
      url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
    ),
  ]);

  // 3. 앱 의존성 및 세션 복구
  const secure = FlutterSecureStorage();
  final transport = SalesApiTransport();
  final deps = AppDependencies(prefs: prefs, secure: secure, transport: transport);

  final authRepo = AuthRepository(deps);
  await authRepo.restoreSession();
  final authController = AuthController(authRepo);

  runApp(
    ProviderScope(
      overrides: [
        appDependenciesProvider.overrideWithValue(deps),
        authControllerProvider.overrideWith((_) => authController),
      ],
      child: const CoadCustomerCallsApp(),
    ),
  );
}
