import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/network/sales_api_transport.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  /// 우선순위: `--dart-define=BASE_URL` → 앱 설정에 저장한 값 → `.env`의 `BASE_URL`
  ///
  /// 이미지 업로드(`POST …/api/storage/b2/upload`)는 Next 주소가 필요합니다. B2 키는 앱 `.env`에 넣지 않습니다.
  String get effectiveBaseUrl {
    if (kBaseUrlDefine.trim().isNotEmpty) {
      return _stripTrailingSlash(kBaseUrlDefine.trim());
    }
    final saved = prefs.getString(StorageKeys.prefsBaseUrl)?.trim() ?? '';
    if (saved.isNotEmpty) {
      return _stripTrailingSlash(saved);
    }
    final fromEnv = dotenv.env['BASE_URL']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return _stripTrailingSlash(fromEnv);
    }
    return '';
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
