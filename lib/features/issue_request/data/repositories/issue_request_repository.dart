import 'dart:async';

import 'package:coad_customer_calls/features/issue_request/data/models/issue_request_dto.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final issueRequestDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(appDependenciesProvider).effectiveBaseUrl;
  if (baseUrl.trim().isEmpty) {
    throw const IssueRequestApiException('서버 주소가 설정되지 않았습니다. BASE_URL 확인 필요');
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          debugPrint('[IssueRequest][REQ] ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint(
            '[IssueRequest][RES] ${response.requestOptions.uri} '
            'status=${response.statusCode}',
          );
        }
        handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint(
            '[IssueRequest][ERR] ${error.requestOptions.uri} '
            'status=${error.response?.statusCode} '
            'body=${error.response?.data}',
          );
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

final issueRequestRepositoryProvider = Provider<IssueRequestRepository>((ref) {
  return IssueRequestRepository(dio: ref.watch(issueRequestDioProvider));
});

class IssueRequestRepository {
  IssueRequestRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<CreateIssueRequestResponseDto> createIssueRequest({
    required int userId,
    required String requestType,
    required String targetName,
    required String? reason,
  }) async {
    final dto = CreateIssueRequestRequestDto(
      userId: userId,
      requestType: requestType,
      targetName: targetName,
      reason: reason,
    );

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/issue-requests',
        data: dto.toJson(),
      );
      final body = response.data;
      if (body == null) {
        throw const IssueRequestApiException('빈 응답입니다.');
      }
      return CreateIssueRequestResponseDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on TimeoutException {
      throw const IssueRequestApiException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<List<IssueRequestDto>> getIssueRequestList({
    required int userId,
    String? status,
  }) async {
    try {
      final query = <String, dynamic>{'user_id': userId};
      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status.trim();
      }
      final response = await _dio.get<List<dynamic>>(
        '/api/issue-requests',
        queryParameters: query,
      );
      final list = response.data ?? const <dynamic>[];
      return list
          .map((item) => IssueRequestDto.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on TimeoutException {
      throw const IssueRequestApiException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<IssueRequestDto> getIssueRequestDetail({required int id}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/issue-requests/$id',
      );
      final body = response.data;
      if (body == null) {
        throw const IssueRequestApiException('빈 응답입니다.');
      }
      return IssueRequestDto.fromJson(body);
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on TimeoutException {
      throw const IssueRequestApiException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  Future<void> updateIssueRequestStatus({
    required int id,
    required String status,
  }) async {
    final body = UpdateIssueRequestStatusRequestDto(status: status);
    try {
      await _dio.patch<void>(
        '/api/issue-requests/$id/status',
        data: body.toJson(),
      );
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on TimeoutException {
      throw const IssueRequestApiException('요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  IssueRequestApiException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const IssueRequestApiException(
        '네트워크 타임아웃이 발생했습니다. 연결 상태를 확인해 주세요.',
      );
    }

    final code = error.response?.statusCode;
    final body = error.response?.data;
    return switch (code) {
      400 => IssueRequestApiException(
        '요청 값이 올바르지 않습니다. 입력값을 확인해 주세요.',
        code: code,
        body: body,
      ),
      401 => IssueRequestApiException(
        '로그인이 필요합니다. 다시 로그인해 주세요.',
        code: code,
        body: body,
      ),
      403 => IssueRequestApiException(
        '권한이 없습니다. 접근 권한을 확인해 주세요.',
        code: code,
        body: body,
      ),
      404 => IssueRequestApiException(
        '요청한 발급요청 데이터를 찾을 수 없습니다.',
        code: code,
        body: body,
      ),
      500 => IssueRequestApiException(
        '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        code: code,
        body: body,
      ),
      _ => IssueRequestApiException(
        '알 수 없는 오류가 발생했습니다. (${code ?? 'no_status'})',
        code: code,
        body: body,
      ),
    };
  }
}

class IssueRequestApiException implements Exception {
  const IssueRequestApiException(this.message, {this.code, this.body});

  final String message;
  final int? code;
  final dynamic body;

  @override
  String toString() => message;
}
