import 'dart:convert';

import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/call_permissions.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coad_customer_calls/services/notification_service.dart';

class AuthRepository {
  AuthRepository(this._deps);

  final AppDependencies _deps;

  AppUser? _user;
  AppUser? get user => _user;

  Future<void> restoreSession() async {
    final cookies = await _deps.secure.read(key: StorageKeys.sessionCookies);
    _deps.transport.cookieHeader = cookies;

    final raw = await _deps.secure.read(key: StorageKeys.userJson);
    if (raw == null || raw.isEmpty) {
      _user = null;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _user = AppUser.fromJson(map);
      if (_user != null) {
        NotificationService.updateTokenInSupabase(_user!.id);
        NotificationService.listenToTokenRefresh(_user!.id);
      }
    } catch (_) {
      _user = null;
    }
  }

  Future<AppUser> login({required String id, required String password}) async {
    final res = await Supabase.instance.client
        .from('users')
        .select('*, groups(name)')
        .eq('id', id)
        .eq('password', password)
        .maybeSingle();

    if (res == null) {
      throw ApiException('아이디 또는 비밀번호가 올바르지 않습니다.', statusCode: 401);
    }

    if (res['is_active'] != true) {
      throw ApiException('사용할 수 없는 계정입니다. 관리자에게 문의하세요.', statusCode: 403);
    }

    final Map<String, dynamic> userMap = {
      ...res,
      'groupName': res['groups'] != null ? res['groups']['name'] : null,
      'permissions': [],
    };

    final u = AppUser.fromJson(userMap);
    if (!canAccessSalesCalls(u)) {
      throw ApiException('고객전화 메뉴 접근 권한이 없습니다. 관리자에게 문의하세요.');
    }

    _user = u;
    await _deps.secure.write(key: StorageKeys.userJson, value: jsonEncode(u.toJson()));
    
    // Register FCM Token
    NotificationService.updateTokenInSupabase(u.id);
    NotificationService.listenToTokenRefresh(u.id);

    _deps.transport.cookieHeader = null;
    await _deps.secure.delete(key: StorageKeys.sessionCookies);

    return u;
  }

  Future<void> logout() async {
    _user = null;
    _deps.transport.cookieHeader = null;
    await _deps.secure.delete(key: StorageKeys.userJson);
    await _deps.secure.delete(key: StorageKeys.sessionCookies);
  }
}
