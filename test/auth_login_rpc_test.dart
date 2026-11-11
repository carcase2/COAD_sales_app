import 'package:coad_customer_calls/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('loginRowFromRpc', () {
    test('null 이면 로그인 실패', () {
      expect(loginRowFromRpc(null), isNull);
    });

    test('비밀번호 키는 지운다', () {
      final row = loginRowFromRpc({
        'id': 'u1',
        'name': '홍길동',
        'password': 'x',
        'groups': {
          'name': 'G',
          'permissions': ['a'],
        },
      });
      expect(row, isNotNull);
      expect(row!.containsKey('password'), isFalse);
      expect(row['groups'], {
        'name': 'G',
        'permissions': ['a'],
      });
    });

    test('목록으로 와도 첫 행을 쓴다', () {
      expect(
        loginRowFromRpc([
          {'id': 'u1'},
        ])?['id'],
        'u1',
      );
      expect(loginRowFromRpc(const []), isNull);
    });

    test('id 가 없으면 실패로 본다', () {
      expect(loginRowFromRpc({'name': 'x'}), isNull);
    });
  });

  group('isMissingRpcError', () {
    test('함수 없음 오류만 예전 경로로 넘긴다', () {
      expect(
        isMissingRpcError(
          const PostgrestException(
            message:
                'Could not find the function public.app_login(p_id, p_password) in the schema cache',
            code: 'PGRST202',
          ),
        ),
        isTrue,
      );
      expect(
        isMissingRpcError(
          const PostgrestException(message: 'boom', code: '500'),
        ),
        isFalse,
      );
      expect(
        isMissingRpcError(
          const PostgrestException(message: 'Not found', code: '404'),
        ),
        isFalse,
      );
    });
  });
}
