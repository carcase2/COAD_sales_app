import 'dart:convert';
import 'dart:io';

import 'package:coad_customer_calls/core/network/api_exception.dart';

/// Android 전용 `dart:io` 클라이언트 — `Set-Cookie` 다중 헤더 처리.
///
/// 요청마다 [HttpClient]를 만들지 않고 인스턴스를 재사용해 keep-alive 연결을 유지합니다.
class SalesApiTransport {
  SalesApiTransport({
    Duration? connectionTimeout,
    Duration? idleTimeout,
  })  : _connectionTimeout = connectionTimeout ?? const Duration(seconds: 20),
        _idleTimeout = idleTimeout ?? const Duration(seconds: 30);

  final Duration _connectionTimeout;
  final Duration _idleTimeout;

  String? cookieHeader;
  HttpClient? _client;

  HttpClient get _http {
    final existing = _client;
    if (existing != null) return existing;
    final client = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = _idleTimeout
      ..autoUncompress = true;
    _client = client;
    return client;
  }

  /// 테스트·로그아웃 등에서 연결 풀을 비울 때 호출.
  void close({bool force = false}) {
    _client?.close(force: force);
    _client = null;
  }

  Future<({int statusCode, String body})> request({
    required String baseUrl,
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? jsonBody,
    Duration? timeout,
  }) async {
    final root = _normalizeBase(baseUrl);
    var uri = Uri.parse('$root${_lead(path)}');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }

    try {
      final client = _http;
      final HttpClientRequest req;
      switch (method.toUpperCase()) {
        case 'GET':
          req = await client.getUrl(uri);
        case 'POST':
          req = await client.postUrl(uri);
        case 'PUT':
          req = await client.putUrl(uri);
        case 'PATCH':
          req = await client.patchUrl(uri);
        case 'DELETE':
          req = await client.deleteUrl(uri);
        default:
          throw ApiException('지원하지 않는 HTTP 메서드입니다: $method');
      }

      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (jsonBody != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(jsonBody));
      } else if (method.toUpperCase() != 'GET') {
        req.headers.contentType = ContentType.json;
      }

      final ch = cookieHeader;
      if (ch != null && ch.isNotEmpty) {
        req.headers.set(HttpHeaders.cookieHeader, ch);
      }

      final wait = timeout ?? (_connectionTimeout + const Duration(seconds: 40));
      final res = await req.close().timeout(
        wait,
        onTimeout: () {
          throw ApiException(
            '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.',
            statusCode: 408,
          );
        },
      );
      final body = await res.transform(utf8.decoder).join();
      _mergeSetCookies(res);
      return (statusCode: res.statusCode, body: body);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('네트워크에 연결할 수 없습니다. (${e.message})');
    } on HttpException catch (e) {
      throw ApiException('HTTP 오류: ${e.message}');
    } on HandshakeException catch (e) {
      throw ApiException('보안 연결에 실패했습니다. (${e.message})');
    } on TlsException catch (e) {
      throw ApiException('보안 연결에 실패했습니다. (${e.message})');
    }
  }

  void _mergeSetCookies(HttpClientResponse res) {
    final parts = <String>[];
    res.headers.forEach((name, values) {
      if (name.toLowerCase() == 'set-cookie') {
        for (final v in values) {
          final nv = v.split(';').first.trim();
          if (nv.isNotEmpty) parts.add(nv);
        }
      }
    });
    if (parts.isEmpty) return;
    final merged = parts.join('; ');
    if (cookieHeader == null || cookieHeader!.isEmpty) {
      cookieHeader = merged;
    } else {
      cookieHeader = '$cookieHeader; $merged';
    }
  }

  static String _normalizeBase(String baseUrl) {
    var s = baseUrl.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  static String _lead(String path) => path.startsWith('/') ? path : '/$path';
}
