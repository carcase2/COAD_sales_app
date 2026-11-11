import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

class ApiException implements Exception {
  ApiException(String message, {this.statusCode})
    : rawMessage = message,
      message = userFacingErrorMessage(message) {
    if (kDebugMode && rawMessage != this.message) {
      debugPrint('ApiException: $rawMessage');
    }
  }

  /// 화면에 보여줄 문구 — 예외 원문(`PostgrestException(...)` 등)은 잘라낸다.
  final String message;

  /// 원문 그대로 — 로그·오류 종류 판별용.
  final String rawMessage;
  final int? statusCode;

  @override
  String toString() => message;
}

class OfflineException extends ApiException {
  OfflineException([super.message = '오프라인 상태입니다. 나중에 자동으로 전송됩니다.']);
}

/// 예외 원문이 시작되는 지점 — `'등록에 실패했습니다: $e'`의 `$e` 부분.
final RegExp _rawErrorStart = RegExp(
  r'(PostgrestException|ClientException|SocketException|TimeoutException|'
  r'AuthException|AuthApiException|StorageException|FunctionException|'
  r'FormatException|HandshakeException|HttpException|DioException|'
  r'PlatformException|FileSystemException|DatabaseException|'
  r'NoSuchMethodError|RangeError|StateError|TypeError|_TypeError|'
  r"Null check operator|Bad state:|Exception:|Instance of '|type '[^']+' is not)",
);

/// `'안내 문구: <예외 원문>'`에서 안내 문구만 남긴다.
/// 원문이 없으면 그대로, 안내 문구가 없으면 일반 안내로 바꾼다.
String userFacingErrorMessage(String message) {
  final match = _rawErrorStart.firstMatch(message);
  if (match == null) return message;
  final isNetwork =
      message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('ClientException') ||
      message.contains('TimeoutException');
  var head = message.substring(0, match.start).trimRight();
  while (head.endsWith(':') || head.endsWith('-') || head.endsWith('(')) {
    head = head.substring(0, head.length - 1).trimRight();
  }
  if (head.isEmpty) {
    return isNetwork
        ? '네트워크 연결을 확인한 뒤 다시 시도해 주세요.'
        : '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
  if (!RegExp(r'[.!?]$').hasMatch(head)) head = '$head.';
  return isNetwork ? '$head 네트워크 연결을 확인해 주세요.' : head;
}
