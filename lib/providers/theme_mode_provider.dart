import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppThemeModePrefKey = 'app_theme_mode_v1';

ThemeMode themeModeFromPref(SharedPreferences prefs) {
  switch (prefs.getString(kAppThemeModePrefKey)) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      // 저장값 없음·알 수 없는 값 → 라이트 모드
      return ThemeMode.light;
  }
}

String themeModePrefValue(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
    case ThemeMode.light:
      return 'light';
  }
}

String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return '어둡게';
    case ThemeMode.system:
      return '시스템 설정';
    case ThemeMode.light:
      return '밝게';
  }
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(themeModeFromPref(_prefs));

  final SharedPreferences _prefs;

  Future<void> setMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _prefs.setString(kAppThemeModePrefKey, themeModePrefValue(mode));
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(appDependenciesProvider).prefs);
});
