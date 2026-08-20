import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('koreanErrorMessage — DNS 실패는 짧은 안내', () {
    final msg = koreanErrorMessage(
      ApiException(
        '통계 데이터를 불러오는데 실패했습니다: ClientException with '
        'SocketException: Failed host lookup: qemerxtickpvjcgowyrd.supabase.co',
      ),
    );
    expect(msg, '네트워크 연결을 확인한 뒤 다시 시도해 주세요.');
    expect(msg.length, lessThan(80));
  });

  test('koreanErrorMessage — StateError 본문을 보여준다', () {
    expect(
      koreanErrorMessage(StateError('명함 인식 API 키가 없습니다.')),
      '명함 인식 API 키가 없습니다.',
    );
  });
}
