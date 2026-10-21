import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 알림 탭으로 이미 열린 업무 목록을 다시 읽게 한다.
final workTasksRefreshProvider = StateProvider<int>((ref) => 0);

class WorkTaskRepository {
  WorkTaskRepository(this._client);

  final SupabaseClient _client;

  Future<WorkTaskBoard> load(String userId) {
    return _call(userId, const {'action': 'list'});
  }

  Future<WorkTaskBoard> create({
    required String userId,
    required String title,
    required String assigneeEmail,
    String detail = '',
    String? dueDate,
    String? priorityId,
  }) {
    return _call(userId, {
      'action': 'create',
      'title': title,
      'detail': detail,
      'assigneeEmail': assigneeEmail,
      'dueDate': dueDate,
      'priorityId': priorityId,
    });
  }

  Future<WorkTaskBoard> setStatus({
    required String userId,
    required String taskId,
    required String action,
  }) {
    return _call(userId, {'action': action, 'taskId': taskId});
  }

  Future<List<WorkComment>> comments({
    required String userId,
    required String taskId,
  }) async {
    final data = await _invoke(userId, {
      'action': 'comments',
      'taskId': taskId,
    });
    return _comments(data);
  }

  Future<List<WorkComment>> addComment({
    required String userId,
    required String taskId,
    required String content,
  }) async {
    final data = await _invoke(userId, {
      'action': 'addComment',
      'taskId': taskId,
      'content': content,
    });
    return _comments(data);
  }

  List<WorkComment> _comments(Map<String, dynamic> data) {
    final raw = data['comments'];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map) WorkComment.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<WorkTaskBoard> _call(String userId, Map<String, dynamic> body) async {
    return WorkTaskBoard.fromJson(await _invoke(userId, body));
  }

  Future<Map<String, dynamic>> _invoke(
    String userId,
    Map<String, dynamic> body,
  ) async {
    final payload = {'userId': userId, ...body};
    try {
      final res = await _client.functions.invoke('work-tasks', body: payload);
      final data = _asMap(res.data);
      if (data['ok'] == false) {
        throw ApiException(
          (data['error'] ?? '업무를 처리하지 못했습니다.').toString(),
          statusCode: res.status,
        );
      }
      if (res.status >= 400) {
        throw ApiException('업무를 처리하지 못했습니다.', statusCode: res.status);
      }
      return data;
    } on ApiException {
      rethrow;
    } on FunctionException catch (e) {
      throw ApiException(_functionMessage(e), statusCode: e.status);
    } catch (_) {
      throw ApiException('업무를 처리하지 못했습니다.');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw ApiException('업무 응답을 읽지 못했습니다.');
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
      return details;
    }
    if (error.status == 403) return '업무관리를 볼 수 있는 계정이 아닙니다.';
    return '업무를 처리하지 못했습니다.';
  }
}
