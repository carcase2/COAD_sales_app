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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  final prefs = await SharedPreferences.getInstance();
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
