import 'dart:async';
import 'package:coad_customer_calls/app.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:coad_customer_calls/core/network/sales_api_transport.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // 앱 시작 시 예기치 않은 중단을 방지하기 위해 전체를 보호합니다.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    try {
      // 1. 필수 로컬 설정 (빠른 작업)
      await initializeDateFormatting('ko_KR', null);
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

      // 2. 환경 변수 및 로컬 DB (동시 실행 가능)
      final initResults = await Future.wait([
        dotenv.load(fileName: ".env"),
        SharedPreferences.getInstance(),
      ]);
      final prefs = initResults[1] as SharedPreferences;

      final supabaseUrl =
          dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
          dotenv.env['SUPABASE_URL'] ??
          '';
      final supabaseKey =
          dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
          dotenv.env['NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY'] ??
          dotenv.env['SUPABASE_ANON_KEY'] ??
          '';

      // 3. 외부 서비스 초기화 — Supabase는 Firebase와 독립이므로
      //    (Firebase → Notification) 체인과 병렬로 실행해 콜드 스타트를 줄임.
      await Future.wait([
        () async {
          try {
            await Supabase.initialize(
              url: supabaseUrl,
              anonKey: supabaseKey,
            );
          } catch (e) {
            debugPrint("Supabase 초기화 실패: $e");
          }
        }(),
        () async {
          try {
            await Firebase.initializeApp();
            await NotificationService.init();
          } catch (e) {
            debugPrint("알림 서비스 초기화 실패: $e");
          }
        }(),
      ]);

      // 4. 앱 의존성 및 세션 복구
      const secure = FlutterSecureStorage();
      final transport = SalesApiTransport();
      final deps = AppDependencies(prefs: prefs, secure: secure, transport: transport);

      final authRepo = AuthRepository(deps);
      await authRepo.restoreSession().catchError((e) => debugPrint("세션 복구 실패: $e"));
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
    } catch (e, stack) {
      debugPrint("치명적인 앱 초기화 에러: $e");
      debugPrint(stack.toString());
      
      // 최소한 앱이라도 실행될 수 있도록 빈 상태로 앱을 띄웁니다.
      runApp(const MaterialApp(home: Scaffold(body: Center(child: Text("앱 초기화 중 오류가 발생했습니다. 다시 시작해 주세요.")))));
    }
  }, (error, stack) {
    debugPrint("Uncaught error: $error");
    debugPrint(stack.toString());
  });
}
