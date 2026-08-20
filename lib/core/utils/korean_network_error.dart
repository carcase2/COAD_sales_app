import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/sales_call_consultation.dart';

/// DNS·소켓 등 연결 실패 여부 (Supabase `ClientException` 포함).
bool isNetworkConnectivityError(Object error) {
  final text = switch (error) {
    ApiException(:final message) => message,
    _ => error.toString(),
  };
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('Network is unreachable') ||
      text.contains('Connection refused') ||
      text.contains('네트워크에 연결할 수 없습니다');
}

String koreanErrorMessage(Object error) {
  if (isNetworkConnectivityError(error)) {
    return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
  }
  if (error is ApiException) return error.message;
  if (error is SalesCallConsultationValidationException) return error.message;
  final cleaned = error
      .toString()
      .replaceFirst(RegExp(r'^Exception: '), '')
      .replaceFirst(RegExp(r'^Bad state: '), '')
      .replaceFirst(RegExp(r'^[A-Za-z]+Error: '), '')
      .trim();
  if (cleaned.isNotEmpty) return cleaned;
  return '알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}
