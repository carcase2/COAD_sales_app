import 'package:coad_customer_calls/core/network/api_exception.dart';

String koreanErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  return '알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}
