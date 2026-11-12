import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/network/timeout_http_client.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('예외 원문은 화면 문구에서 잘라낸다', () {
    final e = ApiException(
      '등록에 실패했습니다: PostgrestException(message: x, code: 23505)',
    );
    expect(e.message, '등록에 실패했습니다.');
    expect(e.rawMessage, contains('23505'));
  });

  test('원문이 없는 문구는 그대로', () {
    expect(ApiException('통화를 찾을 수 없습니다.').message, '통화를 찾을 수 없습니다.');
  });

  test('네트워크 오류는 원문으로 판별한다', () {
    final e = ApiException('목록 실패: SocketException: Failed host lookup');
    expect(e.message, '목록 실패. 네트워크 연결을 확인해 주세요.');
    expect(isNetworkConnectivityError(e), isTrue);
  });

  test('안내 문구 없이 원문만 있으면 일반 안내', () {
    expect(
      ApiException('FormatException: bad').message,
      '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    );
  });

  test('경로별 시간 제한', () {
    Duration t(String p) =>
        TimeoutHttpClient.timeoutFor(Uri.parse('https://x.supabase.co$p'));
    expect(t('/rest/v1/sales_calls'), TimeoutHttpClient.restTimeout);
    expect(t('/functions/v1/ai'), TimeoutHttpClient.functionsTimeout);
    expect(t('/storage/v1/object/a'), TimeoutHttpClient.storageTimeout);
  });
}
