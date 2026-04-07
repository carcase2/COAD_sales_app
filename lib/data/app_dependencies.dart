import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/network/sales_api_transport.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDependencies {
  AppDependencies({
    required this.prefs,
    required this.secure,
    required this.transport,
  });

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
  final SalesApiTransport transport;

  /// `--dart-define=BASE_URL=...` 우선, 없으면 설정 화면에서 저장한 값.
  String get effectiveBaseUrl {
    if (kBaseUrlDefine.trim().isNotEmpty) {
      return _stripTrailingSlash(kBaseUrlDefine.trim());
    }
    final saved = prefs.getString(StorageKeys.prefsBaseUrl)?.trim() ?? '';
    return _stripTrailingSlash(saved);
  }

  Future<void> setDebugBaseUrl(String url) async {
    final t = url.trim();
    if (t.isEmpty) {
      await prefs.remove(StorageKeys.prefsBaseUrl);
      return;
    }
    await prefs.setString(StorageKeys.prefsBaseUrl, _stripTrailingSlash(t));
  }

  static String _stripTrailingSlash(String s) {
    if (s.endsWith('/')) return s.substring(0, s.length - 1);
    return s;
  }
}
