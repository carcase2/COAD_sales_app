import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/models/work_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 요청 알림을 누르면 열린 부서 요청 화면을 다시 읽게 한다.
final workRequestsRefreshProvider = StateProvider<int>((ref) => 0);

/// 이미 열린 요청 화면에서 알림을 누르면 이 요청을 연다. 열고 나면 null.
final workRequestOpenProvider = StateProvider<String?>((ref) => null);

/// 서버 함수 `work-requests` — 모든 부서 계정이 쓴다.
class WorkRequestRepository {
  WorkRequestRepository(this._client);

  final SupabaseClient _client;

  Future<WorkRequestBoard> load(String userId) =>
      _call(userId, const {'action': 'list'});

  Future<WorkRequestBoard> create({
    required String userId,
    required String toGroup,
    required String title,
    String detail = '',
    String? dueDate,
    String priority = '보통',
  }) {
    return _call(userId, {
      'action': 'create',
      'toGroup': toGroup,
      'title': title,
      'detail': detail,
      'dueDate': dueDate ?? '',
      'priority': priority,
    });
  }

  /// 바뀐 칸만. [dueDate] '' 이면 기한을 지운다.
  Future<WorkRequestBoard> update({
    required String userId,
    required String requestId,
    String? title,
    String? detail,
    String? dueDate,
    String? priority,
  }) {
    return _call(userId, {
      'action': 'update',
      'requestId': requestId,
      'title': ?title,
      'detail': ?detail,
      'dueDate': ?dueDate,
      'priority': ?priority,
    });
  }

  /// [action] accept · reject · hold
  Future<WorkRequestBoard> decide({
    required String userId,
    required String requestId,
    required String action,
    String note = '',
  }) {
    return _call(userId, {
      'action': action,
      'requestId': requestId,
      'note': note,
    });
  }

  Future<WorkRequestBoard> progress({
    required String userId,
    required String requestId,
    required String progress,
  }) {
    return _call(userId, {
      'action': 'progress',
      'requestId': requestId,
      'progress': progress,
    });
  }

  Future<WorkRequestBoard> cancel({
    required String userId,
    required String requestId,
  }) {
    return _call(userId, {'action': 'cancel', 'requestId': requestId});
  }

  Future<WorkRequestBoard> _call(
    String userId,
    Map<String, dynamic> body,
  ) async {
    final payload = {'userId': userId, ...body};
    try {
      final res = await _client.functions.invoke(
        'work-requests',
        body: payload,
      );
      final data = _asMap(res.data);
      if (data['ok'] == false) {
        throw ApiException(
          (data['error'] ?? '업무 요청을 처리하지 못했습니다.').toString(),
          statusCode: res.status,
        );
      }
      return WorkRequestBoard.fromJson(data);
    } on ApiException {
      rethrow;
    } on FunctionException catch (e) {
      throw ApiException(_functionMessage(e), statusCode: e.status);
    } catch (_) {
      throw ApiException('업무 요청을 처리하지 못했습니다.');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw ApiException('업무 요청 응답을 읽지 못했습니다.');
  }

  String _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    if (details is String && details.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      } catch (_) {}
    }
    if (error.status == 404) return '부서 요청 서버가 아직 준비되지 않았습니다.';
    return '업무 요청을 처리하지 못했습니다.';
  }
}
