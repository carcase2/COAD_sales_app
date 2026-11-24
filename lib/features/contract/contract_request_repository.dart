import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/features/contract/contract_request_model.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ContractViewer {
  const ContractViewer({
    required this.id,
    required this.name,
    required this.canHandle,
  });

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

  Uri _uri(String path, [Map<String, String>? q]) => Uri.parse(
    '$_base/api/contract-requests$path',
  ).replace(queryParameters: q);

  Future<dynamic> _call(
    String userId,
    String method, [
    Map<String, dynamic>? body,
    String path = '',
  ]) async {
    final uri = _uri(path);
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
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.patch(uri, headers: headers, body: jsonEncode(body)),
      }.timeout(const Duration(seconds: 30));
    } catch (_) {
      throw Exception('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    return _decode(res);
  }

  /// 응답 해석 + 오류 메시지 (404 에 본문이 없으면 아직 배포 전)
  static dynamic _decode(http.Response res) {
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

  Future<({ContractViewer viewer, List<ContractRequest> requests})> list(
    String userId,
  ) async {
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

  Future<ContractRequest> _one(
    String userId,
    String method,
    Map<String, dynamic> body,
  ) async {
    final j = await _call(userId, method, body);
    return ContractRequest.fromJson(Map<String, dynamic>.from(j as Map));
  }

  Future<ContractRequest> create(String userId, ContractFields f) =>
      _one(userId, 'POST', f.toJson());

  Future<ContractRequest> update(String userId, String id, ContractFields f) =>
      _one(userId, 'PATCH', {...f.toJson(), 'id': id, 'action': 'update'});

  Future<ContractRequest> complete(String userId, String id, String note) =>
      _one(userId, 'PATCH', {
        'id': id,
        'action': 'complete',
        'handled_note': note,
      });

  Future<ContractRequest> cancel(String userId, String id) =>
      _one(userId, 'PATCH', {'id': id, 'action': 'cancel'});

  Future<ContractRequest> reopen(String userId, String id) =>
      _one(userId, 'PATCH', {'id': id, 'action': 'reopen'});

  Map<String, String> _auth(String userId) => {
    'Accept': 'application/json',
    'x-user-id': Uri.encodeComponent(userId),
  };

  Future<dynamic> _multipart(
    String userId,
    String path,
    Map<String, String> fields,
    File file,
    String contentType,
  ) async {
    final req = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_auth(userId))
      ..fields.addAll(fields)
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.uri.pathSegments.last,
          contentType: _mediaType(contentType),
        ),
      );
    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 90)),
      );
    } catch (_) {
      throw Exception('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    return _decode(res);
  }

  static MediaType _mediaType(String t) {
    final i = t.indexOf('/');
    return i < 0
        ? MediaType('application', 'octet-stream')
        : MediaType(t.substring(0, i), t.substring(i + 1));
  }

  /// NEW MES 대분류 → 제품 목록. 실패하면 빈 목록 (직접 입력).
  Future<List<CatalogCategory>> catalog(String userId) async {
    try {
      final j = await _call(userId, 'GET', null, '/products') as Map;
      return [
        for (final c in (j['categories'] as List? ?? const []))
          if (c is Map) CatalogCategory.fromJson(Map<String, dynamic>.from(c)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 사업자등록증·명함 올리기 (사진·PDF)
  Future<ContractRequest> upload(
    String userId,
    String id,
    String kind,
    File file,
    String contentType,
  ) async {
    final j = await _multipart(
      userId,
      '/file',
      {'id': id, 'kind': kind},
      file,
      contentType,
    );
    return ContractRequest.fromJson(Map<String, dynamic>.from(j as Map));
  }

  Future<ContractRequest> removeFile(
    String userId,
    String id,
    String fileId,
  ) async {
    final res = await http
        .delete(
          _uri('/file', {'id': id, 'fileId': fileId}),
          headers: _auth(userId),
        )
        .timeout(const Duration(seconds: 30));
    return ContractRequest.fromJson(
      Map<String, dynamic>.from(_decode(res) as Map),
    );
  }

  /// 첨부 보기용 잠깐 쓰는 서명 주소
  Future<String> fileUrl(String userId, String id, String fileId) async {
    final res = await http
        .get(
          _uri('/file', {'id': id, 'fileId': fileId}),
          headers: _auth(userId),
        )
        .timeout(const Duration(seconds: 30));
    return '${(_decode(res) as Map)['url'] ?? ''}';
  }

  /// 사업자등록증·명함 자동 인식 (서버가 저장하지 않는다)
  Future<RecognizedDocument> recognize(
    String userId,
    String kind,
    File file,
    String contentType,
  ) async {
    final j = await _multipart(
      userId,
      '/recognize',
      {'kind': kind},
      file,
      contentType,
    );
    return RecognizedDocument(
      Map<String, dynamic>.from((j as Map)['result'] as Map? ?? {}),
    );
  }

  /// 요청 내용으로 만든 공사계약서 엑셀을 임시 폴더에 저장하고 그 파일을 돌려준다.
  Future<File> downloadDocument(String userId, String id) async {
    final http.Response res;
    try {
      res = await http
          .get(_uri('/document', {'id': id}), headers: _auth(userId))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw Exception('서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    }
    if (res.statusCode != 200) {
      _decode(res);
      throw Exception('계약서를 만들지 못했습니다 (${res.statusCode})');
    }
    final cd = res.headers['content-disposition'] ?? '';
    final enc = RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(cd)?[1];
    final name = (enc != null ? Uri.decodeComponent(enc) : '계약서.xlsx')
        .replaceAll(RegExp(r'[\\/]'), '');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(res.bodyBytes);
    return f;
  }
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
