import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/models/checksheet_archive.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// MES 아카이브 사진 종류.
enum MesArchiveKind {
  checksheet,
  installAfter,
}

/// MES 아카이브 체크시트(TP1) · 시공후 사진(TP3) 읽기 전용 저장소.
///
/// 1) `BASE_URL` 있으면 Next `/api/archive/*` (체크시트만)
/// 2) 없으면 Supabase Edge Function
///
/// service role · R2 시크릿은 서버(Edge/Next)에만 둔다.
class ChecksheetArchiveRepository {
  ChecksheetArchiveRepository(this._deps);

  final AppDependencies _deps;

  String? get _baseUrl {
    final b = _deps.effectiveBaseUrl.trim();
    return b.isEmpty ? null : b;
  }

  String get _supabaseUrl {
    final u = dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
        dotenv.env['SUPABASE_URL'] ??
        Supabase.instance.client.rest.url.toString().replaceAll('/rest/v1', '');
    return u.replaceAll(RegExp(r'/$'), '');
  }

  String get _supabaseAnonKey {
    return dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
        dotenv.env['SUPABASE_ANON_KEY'] ??
        '';
  }

  /// Edge Function 미디어 요청 시 CachedNetworkImage 헤더.
  Map<String, String>? mediaHttpHeadersForUrl(String absoluteUrl) {
    if (!absoluteUrl.contains('/functions/v1/archive-media')) {
      return null;
    }
    final anon = _supabaseAnonKey;
    if (anon.isEmpty) return null;
    return {
      'apikey': anon,
      'Authorization': 'Bearer $anon',
    };
  }

  /// 절대 미디어 URL (CachedNetworkImage용).
  String absoluteMediaUrl(String mediaPath, {String? userId}) {
    // Edge Function 경로 마커
    if (mediaPath.startsWith('edge:')) {
      final rest = mediaPath.substring('edge:'.length); // archive-media?id=...
      final qIndex = rest.indexOf('?');
      final name = qIndex >= 0 ? rest.substring(0, qIndex) : rest;
      final query = qIndex >= 0 ? rest.substring(qIndex + 1) : '';
      final uri = Uri.parse('$_supabaseUrl/functions/v1/$name')
          .replace(query: query.isEmpty ? null : query);
      return uri.toString();
    }

    if (mediaPath.startsWith('http://') || mediaPath.startsWith('https://')) {
      return mediaPath;
    }

    final base = _baseUrl;
    if (base == null) {
      // Next 없이 edge 미디어로 재해석 시도
      final idMatch = RegExp(r'[?&]id=([^&]+)').firstMatch(mediaPath);
      if (idMatch != null) {
        return absoluteMediaUrl(
          'edge:archive-media?id=${idMatch.group(1)}',
          userId: userId,
        );
      }
      throw ApiException('미디어 URL을 만들 수 없습니다.');
    }

    final path = mediaPath.startsWith('/') ? mediaPath : '/$mediaPath';
    if (userId != null &&
        userId.isNotEmpty &&
        !path.contains('user_id=')) {
      final sep = path.contains('?') ? '&' : '?';
      return '$base$path${sep}user_id=${Uri.encodeQueryComponent(userId)}';
    }
    return '$base$path';
  }

  /// 시공후 사진 모델. 사양서(`spec_sheet_models`) 전체 이름.
  Future<List<InstallAfterModelOption>> fetchInstallAfterModels() async {
    try {
      final res = await Supabase.instance.client
          .from('spec_sheet_models')
          .select('name')
          .order('sort_order')
          .order('name');
      final byCode = <String, InstallAfterModelOption>{};
      for (final row in res) {
        if (row is! Map) continue;
        final name = (row['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final code = _cSeriesCodeFromName(name);
        byCode.putIfAbsent(
          code,
          () => InstallAfterModelOption(code: code, label: name),
        );
      }
      final list = byCode.values.toList()
        ..sort((a, b) => _compareCSeriesCodes(a.code, b.code));
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return List<InstallAfterModelOption>.from(_fallbackInstallAfterModels);
  }

  Future<ChecksheetSearchResult> search({
    required String query,
    int? year,
    int? month,
    String? modelName,
    int limit = 50,
    int offset = 0,
    String? userId,
    MesArchiveKind kind = MesArchiveKind.checksheet,
  }) async {
    final base = _baseUrl;
    if (base != null && kind == MesArchiveKind.checksheet) {
      try {
        return await _searchViaNext(
          baseUrl: base,
          query: query,
          year: year,
          month: month,
          limit: limit,
          offset: offset,
          userId: userId,
        );
      } catch (e) {
        // Next 실패 시 Edge 폴백
        if (e is ApiException && e.statusCode == 404) {
          return _searchViaEdge(
            query: query,
            year: year,
            month: month,
            modelName: modelName,
            limit: limit,
            offset: offset,
            kind: kind,
          );
        }
        // BASE_URL 이 잘못된 경우 등 — Edge 시도
        try {
          return await _searchViaEdge(
            query: query,
            year: year,
            month: month,
            modelName: modelName,
            limit: limit,
            offset: offset,
            kind: kind,
          );
        } catch (_) {
          rethrow;
        }
      }
    }

    return _searchViaEdge(
      query: query,
      year: year,
      month: month,
      modelName: modelName,
      limit: limit,
      offset: offset,
      kind: kind,
    );
  }

  Future<ChecksheetSearchResult> _searchViaNext({
    required String baseUrl,
    required String query,
    int? year,
    int? month,
    int limit = 50,
    int offset = 0,
    String? userId,
  }) async {
    final q = query.trim();
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (q.isNotEmpty) params['q'] = q;
    if (year != null && year > 0) params['year'] = '$year';
    if (month != null && month >= 1 && month <= 12) params['month'] = '$month';
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;

    final res = await _deps.transport.request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/api/archive/checksheets',
      query: params,
    );

    if (res.statusCode == 404) {
      throw ApiException('체크시트 API가 서버에 없습니다.', statusCode: 404);
    }
    return _parseSearchBody(res.statusCode, res.body);
  }

  Future<ChecksheetSearchResult> _searchViaEdge({
    required String query,
    int? year,
    int? month,
    String? modelName,
    int limit = 50,
    int offset = 0,
    MesArchiveKind kind = MesArchiveKind.checksheet,
  }) async {
    final anon = _supabaseAnonKey;
    if (anon.isEmpty) {
      throw ApiException(
        'Supabase 설정이 없습니다. .env의 NEXT_PUBLIC_SUPABASE_ANON_KEY를 확인하세요.',
      );
    }

    final q = query.trim();
    final model = (modelName ?? '').trim();
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (q.isNotEmpty) params['q'] = q;
    if (model.isNotEmpty) params['model'] = model;
    // 시공후는 이미 배포된 archive-checksheets 에 kind 로 합침.
    if (kind == MesArchiveKind.installAfter) {
      params['kind'] = 'install_after';
    } else {
      if (year != null && year > 0) params['year'] = '$year';
      if (month != null && month >= 1 && month <= 12) {
        params['month'] = '$month';
      }
    }

    final uri = Uri.parse('$_supabaseUrl/functions/v1/archive-checksheets')
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {
        'apikey': anon,
        'Authorization': 'Bearer $anon',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 45));

    if (res.statusCode == 404) {
      throw ApiException(
        'Edge Function이 배포되지 않았습니다. archive-checksheets 재배포가 필요합니다.',
        statusCode: 404,
      );
    }

    return _parseSearchBody(res.statusCode, res.body, kind: kind);
  }

  ChecksheetSearchResult _parseSearchBody(
    int statusCode,
    String body, {
    MesArchiveKind kind = MesArchiveKind.checksheet,
  }) {
    final label = kind == MesArchiveKind.installAfter ? '시공후 사진' : '체크시트';
    if (statusCode == 403) {
      throw ApiException('$label 조회 권한이 없습니다.', statusCode: 403);
    }
    if (statusCode == 503) {
      throw ApiException(
        'R2 미디어 설정이 없습니다. 관리자에게 문의하세요.',
        statusCode: 503,
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      String msg = '$label 검색에 실패했습니다.';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] != null) {
          msg = '${decoded['error']}';
        }
      } catch (_) {}
      // 긴 영문/.env 메시지 축약
      if (msg.length > 120) {
        msg = '${msg.substring(0, 117)}...';
      }
      throw ApiException(msg, statusCode: statusCode);
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('응답 형식이 올바르지 않습니다.');
    }
    if (decoded['success'] == false) {
      throw ApiException(
        '${decoded['error'] ?? '$label 검색에 실패했습니다.'}',
      );
    }
    return ChecksheetSearchResult.fromJson(decoded);
  }
}

final checksheetArchiveRepositoryProvider =
    Provider<ChecksheetArchiveRepository>((ref) {
  return ChecksheetArchiveRepository(ref.watch(appDependenciesProvider));
});

/// 사양서 모델명에서 검색용 코드만 추출 (C-1 Standard → C-1).
String _cSeriesCodeFromName(String name) {
  final m = RegExp(r'^C-(\d+)', caseSensitive: false).firstMatch(name.trim());
  if (m == null) return name.trim();
  return 'C-${m.group(1)!}';
}

int _compareCSeriesCodes(String a, String b) {
  final ra = RegExp(r'^C-(\d+)(.*)$', caseSensitive: false).firstMatch(a);
  final rb = RegExp(r'^C-(\d+)(.*)$', caseSensitive: false).firstMatch(b);
  if (ra != null && rb != null) {
    final na = int.parse(ra.group(1)!);
    final nb = int.parse(rb.group(1)!);
    if (na != nb) return na.compareTo(nb);
    return (ra.group(2) ?? '').compareTo(rb.group(2) ?? '');
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

const _fallbackInstallAfterModels = [
  InstallAfterModelOption(code: 'C-1', label: 'C-1 Standard'),
  InstallAfterModelOption(code: 'C-2', label: 'C-2 Deluxe'),
  InstallAfterModelOption(code: 'C-3', label: 'C-3 Premium'),
  InstallAfterModelOption(code: 'C-5', label: 'C-5 Snail Door'),
  InstallAfterModelOption(code: 'C-20', label: 'C-20 Stacking Door'),
  InstallAfterModelOption(code: 'C-30', label: 'C-30 Overhead Door'),
  InstallAfterModelOption(code: 'C-40', label: 'C-40 차고문'),
  InstallAfterModelOption(code: 'C-50', label: 'C-50 내풍압셔터'),
  InstallAfterModelOption(code: 'C-51', label: 'C-51 내풍압단열셔터'),
  InstallAfterModelOption(code: 'C-52', label: 'C-52 철재방화셔터'),
  InstallAfterModelOption(code: 'C-53', label: 'C-53 스크린방화셔터'),
  InstallAfterModelOption(code: 'C-54', label: 'C-54 AL 이중압출셔터'),
  InstallAfterModelOption(code: 'C-55', label: 'C-55 AL 이중압출단열셔터'),
  InstallAfterModelOption(code: 'C-56', label: 'C-56 AL 고속셔터'),
  InstallAfterModelOption(code: 'C-57', label: 'C-57 방범셔터'),
  InstallAfterModelOption(code: 'C-60', label: 'C-60 유리자동문'),
];
