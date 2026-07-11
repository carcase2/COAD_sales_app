abstract final class StorageKeys {
  static const userJson = 'auth_user_json';
  static const sessionCookies = 'auth_session_cookies';
  static const prefsBaseUrl = 'base_url';
  static const savedLoginId = 'saved_login_id';
  static const savedLoginPassword = 'saved_login_password';
  static const rememberLoginId = 'remember_login_id';
  static const autoLoginEnabled = 'auto_login_enabled';
  static const shutterPriceGridCache = 'shutter_price_grid_cache';
  static const shutterPriceUnitCache = 'shutter_price_unit_cache';
  static const shutterPriceCompanyCache = 'shutter_price_company_cache';
  static const shutterPriceCachedAt = 'shutter_price_cached_at';
  /// 백그라운드 isolate 알림 탭 → 메인 앱으로 전달할 FCM/로컬 payload
  static const pendingNotificationPayload = 'pending_notification_payload';
}
