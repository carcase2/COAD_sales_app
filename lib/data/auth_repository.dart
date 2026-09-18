import 'dart:convert';

import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/call_permissions.dart';
import 'package:coad_customer_calls/core/utils/mes_permissions.dart';
import 'package:coad_customer_calls/data/mes_repository.dart';
import 'package:coad_customer_calls/data/mes_photo_queue.dart';
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
        .select('*, groups(name, permissions), coad_branch(name)')
        .eq('id', id)
        .eq('password', password)
        .maybeSingle();

    if (res == null) {
      throw ApiException('아이디 또는 비밀번호가 올바르지 않습니다.', statusCode: 401);
    }

    if (res['is_active'] != true) {
      throw ApiException('사용할 수 없는 계정입니다. 관리자에게 문의하세요.', statusCode: 403);
    }

    Map<String, dynamic>? groupMap;
    final groups = res['groups'];
    if (groups is Map<String, dynamic>) {
      groupMap = groups;
    } else if (groups is Map) {
      groupMap = Map<String, dynamic>.from(groups);
    } else if (groups is List && groups.isNotEmpty && groups.first is Map) {
      groupMap = Map<String, dynamic>.from(groups.first as Map);
    }

    final mergedPerms = <String>[];
    void addPerms(dynamic raw) {
      if (raw is! List) return;
      for (final e in raw) {
        final s = e.toString().trim();
        if (s.isNotEmpty && !mergedPerms.contains(s)) mergedPerms.add(s);
      }
    }

    addPerms(res['permissions']);
    addPerms(groupMap?['permissions']);

    final groupId = res['group_id']?.toString();
    final branchId = res['branch_id']?.toString();
    final title = (res['title']?.toString() ?? '').trim();
    if (groupId != null && groupId.isNotEmpty) {
      try {
        final rules = await Supabase.instance.client
            .from('access_rules')
            .select('group_id, branch_id, title, permissions')
            .eq('group_id', groupId);
        final picked = _pickAccessPermissions(
          rules is List ? rules : const [],
          branchId,
          title.isEmpty ? '팀원' : title,
        );
        if (picked.isNotEmpty) {
          mergedPerms
            ..clear()
            ..addAll(picked);
        }
      } catch (_) {}
    }

    String? branchName;
    final branch = res['coad_branch'];
    if (branch is Map) {
      branchName = branch['name']?.toString();
    }

    final Map<String, dynamic> userMap = {
      ...res,
      'groupName': groupMap?['name'] ?? res['groups']?['name'],
      'permissions': mergedPerms,
      if (branchName != null) 'branch_name': branchName,
    };

    final u = AppUser.fromJson(userMap);
    if (!canAccessSalesCalls(u) && !canAccessMes(u)) {
      throw ApiException('메뉴 접근 권한이 없습니다. 관리자에게 문의하세요.');
    }

    _user = u;
    final mes = MesRepository(_deps);
    await mes.login(id, password);
    try {
      await MesPhotoQueue.flush(mes);
    } catch (_) {}
    await _deps.secure.write(
      key: StorageKeys.userJson,
      value: jsonEncode(u.toJson()),
    );

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
    await MesRepository(_deps).logout();
    await _deps.secure.delete(key: StorageKeys.userJson);
    await _deps.secure.delete(key: StorageKeys.sessionCookies);
    // 사용자가 의도적으로 로그아웃한 경우 자동 재로그인을 막는다.
    await _deps.secure.write(key: StorageKeys.autoLoginEnabled, value: 'false');
    await _deps.secure.delete(key: StorageKeys.savedLoginPassword);
  }
}

int _ruleScore(Map rule, String? branchId, String? title) {
  final rb = rule['branch_id']?.toString();
  final rt = rule['title']?.toString();
  if (rb != null && rb.isNotEmpty && branchId != null && rb != branchId) {
    return -1;
  }
  if (rb != null && rb.isNotEmpty && (branchId == null || branchId.isEmpty)) {
    return -1;
  }
  if (rt != null && rt.isNotEmpty && title != null && rt != title) return -1;
  if (rt != null && rt.isNotEmpty && (title == null || title.isEmpty)) {
    return -1;
  }
  var score = 0;
  if (rb != null && rb.isNotEmpty && rb == branchId) {
    score += 4;
  } else if (rb == null || rb.isEmpty) {
    score += 1;
  }
  if (rt != null && rt.isNotEmpty && rt == title) {
    score += 4;
  } else if (rt == null || rt.isEmpty) {
    score += 1;
  }
  return score;
}

List<String> _pickAccessPermissions(
  List<dynamic> rules,
  String? branchId,
  String? title,
) {
  var best = -1;
  final matched = <List<String>>[];
  for (final raw in rules) {
    if (raw is! Map) continue;
    final score = _ruleScore(Map<String, dynamic>.from(raw), branchId, title);
    if (score < 0) continue;
    final perms = <String>[];
    final p = raw['permissions'];
    if (p is List) {
      for (final e in p) {
        final s = e.toString().trim();
        if (s.isNotEmpty) perms.add(s);
      }
    }
    if (score > best) {
      best = score;
      matched
        ..clear()
        ..add(perms);
    } else if (score == best) {
      matched.add(perms);
    }
  }
  if (matched.isEmpty) return const [];
  final out = <String>[];
  for (final list in matched) {
    for (final p in list) {
      if (!out.contains(p)) out.add(p);
    }
  }
  return out;
}
