import 'dart:async';

import 'package:http/http.dart' as http;

/// Supabase 호출에 시간 제한을 거는 HTTP 클라이언트.
///
/// 신호가 약한 곳에서 응답이 끝없이 안 오면 로딩 표시가 계속 도는데,
/// 제한 시간이 지나면 [http.ClientException]으로 끊어 화면이 오류·재시도로 넘어가게 한다.
/// 제한은 "응답이 시작될 때까지"만 잰다 — 큰 파일 내려받기 본문은 끊지 않는다.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// 일반 조회·저장.
  static const Duration restTimeout = Duration(seconds: 20);

  /// Edge Function — AI 추출 등 오래 걸리는 작업이 있다.
  static const Duration functionsTimeout = Duration(seconds: 90);

  /// 파일 올리기·내려받기.
  static const Duration storageTimeout = Duration(minutes: 3);

  static Duration timeoutFor(Uri url) {
    final path = url.path;
    if (path.contains('/storage/v1/')) return storageTimeout;
    if (path.contains('/functions/v1/')) return functionsTimeout;
    return restTimeout;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final limit = timeoutFor(request.url);
    return _inner
        .send(request)
        .timeout(
          limit,
          onTimeout: () => throw http.ClientException(
            '요청 시간이 초과되었습니다 (${limit.inSeconds}초)',
            request.url,
          ),
        );
  }

  @override
  void close() => _inner.close();
}
