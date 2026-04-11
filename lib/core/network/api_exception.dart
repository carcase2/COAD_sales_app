class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class OfflineException extends ApiException {
  OfflineException([String message = '오프라인 상태입니다. 나중에 자동으로 전송됩니다.']) : super(message);
}
