import 'dart:convert';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/features/contract/contract_request_model.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ContractViewer {
  const ContractViewer({required this.id, required this.name, required this.canHandle});

  final String id;
  final String name;

  /// 총무·관리자: 완료 처리 가능
  final bool canHandle;
}

/// contract_requests 테이블은 service role 전용이라 COAD_home `/api/contract-requests` 를 거친다.
class ContractRequestRepository {
  ContractRequestRepository(this._deps);

  final AppDependencies _deps;

  String get _base {
    final configured = _deps.effectiveBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    final v = dotenv.env['COAD_HOME_URL']?.trim() ?? '';
    if (v.isNotEmpty) return v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    return kDefaultCoadHomeUrl;
  }

  Future<dynamic> _call(String userId, String method, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$_base/api/contract-requests');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-user-id': Uri.encodeComponent(userId),
    };
    final http.Response res;
    try {
      res = await switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
        _ => http.patch(uri, headers: headers, body: jsonEncode(body)),
      }.timeout(const Duration(seconds: 30));
    } catch (_) {
      throw Exception('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    dynamic json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      json = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = json is Map ? json['error']?.toString() : null;
      if (res.statusCode == 404 && msg == null) {
        throw Exception('인트라넷에 계약서요청 기능이 아직 배포되지 않았습니다.');
      }
      throw Exception(msg ?? '요청 실패 (${res.statusCode})');
    }
    return json;
  }

  Future<({ContractViewer viewer, List<ContractRequest> requests})> list(String userId) async {
    final j = await _call(userId, 'GET') as Map;
    final v = Map<String, dynamic>.from(j['viewer'] as Map? ?? {});
    return (
      viewer: ContractViewer(
        id: '${v['id'] ?? userId}',
        name: '${v['name'] ?? ''}',
        canHandle: v['canHandle'] == true,
      ),
      requests: [
        for (final r in (j['requests'] as List? ?? const []))
          if (r is Map) ContractRequest.fromJson(Map<String, dynamic>.from(r)),
      ],
    );
  }

  Future<ContractRequest> _one(String userId, String method, Map<String, dynamic> body) async {
    final j = await _call(userId, method, body);
    return ContractRequest.fromJson(Map<String, dynamic>.from(j as Map));
  }

  Future<ContractRequest> create(String userId, ContractFields f) =>
      _one(userId, 'POST', f.toJson());

  Future<ContractRequest> update(String userId, String id, ContractFields f) =>
      _one(userId, 'PATCH', {...f.toJson(), 'id': id, 'action': 'update'});

  Future<ContractRequest> complete(String userId, String id, String note) =>
      _one(userId, 'PATCH', {'id': id, 'action': 'complete', 'handled_note': note});

  Future<ContractRequest> cancel(String userId, String id) =>
      _one(userId, 'PATCH', {'id': id, 'action': 'cancel'});

  Future<ContractRequest> reopen(String userId, String id) =>
      _one(userId, 'PATCH', {'id': id, 'action': 'reopen'});
}

final contractRequestRepositoryProvider = Provider<ContractRequestRepository>(
  (ref) => ContractRequestRepository(ref.watch(appDependenciesProvider)),
);

/// 발급요청 메뉴 배지: 아직 처리하지 않은(요청) 건수.
final contractOpenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(authControllerProvider)?.id ?? '';
  if (uid.isEmpty) return 0;
  final r = await ref.read(contractRequestRepositoryProvider).list(uid);
  return r.requests.where((e) => e.status == '요청').length;
});
