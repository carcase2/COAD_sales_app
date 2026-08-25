import 'dart:convert';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// MES Next 앱 주소. 비어 있으면 메뉴를 숨긴다. 나중에 운영 URL로 바꾸면 됨.
String get mesApiUrl {
  final fromEnv = dotenv.env['MES_API_URL']?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
  return kBaseUrlDefine.trim().isNotEmpty ? kBaseUrlDefine.trim() : '';
}

class MesRepository {
  MesRepository(this._deps);
  final AppDependencies _deps;
  String? _token;
  String? get token => _token;

  Future<void> restore() async {
    _token = await _deps.secure.read(key: StorageKeys.mesJwt);
  }

  Future<void> login(String id, String password) async {
    final base = mesApiUrl;
    if (base.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('$base/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'password': password}),
      );
      if (res.statusCode != 200) return;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      _token = map['token'] as String?;
      if (_token != null) {
        await _deps.secure.write(key: StorageKeys.mesJwt, value: _token!);
      }
    } catch (_) {
      // MES 서버가 꺼져 있어도 영업 앱 로그인은 유지
    }
  }

  Future<void> logout() async {
    _token = null;
    await _deps.secure.delete(key: StorageKeys.mesJwt);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(
      Uri.parse('$mesApiUrl$path'),
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('$mesApiUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(body ?? {}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
