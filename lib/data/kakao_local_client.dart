import 'dart:convert';

import 'package:coad_customer_calls/core/config/env.dart';
import 'package:http/http.dart' as http;

class KakaoPlaceHit {
  const KakaoPlaceHit({
    required this.address,
    required this.lat,
    required this.lng,
    this.roadAddress,
    this.placeName,
  });

  final String address;
  final String? roadAddress;
  final String? placeName;
  final double lat;
  final double lng;

  String get displayAddress {
    final road = roadAddress?.trim() ?? '';
    if (road.isNotEmpty) return road;
    return address.trim();
  }

  /// 카카오맵처럼 주소 뒤에 상호를 붙임. 예: 화성시 현대기아로 202-37 코아드
  String get suggestionLabel {
    final addr = displayAddress;
    final place = placeName?.trim() ?? '';
    if (place.isEmpty) return addr;
    if (addr.contains(place)) return addr;
    return '$addr $place';
  }
}

List<KakaoPlaceHit> parseKakaoKeywordDocuments(List<dynamic> documents) {
  final out = <KakaoPlaceHit>[];
  for (final raw in documents) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final lat = double.tryParse('${map['y'] ?? ''}');
    final lng = double.tryParse('${map['x'] ?? ''}');
    if (lat == null || lng == null) continue;
    final address = (map['address_name'] ?? '').toString().trim();
    final road = (map['road_address_name'] ?? '').toString().trim();
    final place = (map['place_name'] ?? '').toString().trim();
    if (address.isEmpty && road.isEmpty && place.isEmpty) continue;
    out.add(
      KakaoPlaceHit(
        address: address.isNotEmpty
            ? address
            : (road.isNotEmpty ? road : place),
        roadAddress: road.isEmpty ? null : road,
        placeName: place.isEmpty ? null : place,
        lat: lat,
        lng: lng,
      ),
    );
  }
  return out;
}

List<KakaoPlaceHit> parseKakaoAddressDocuments(List<dynamic> documents) {
  final out = <KakaoPlaceHit>[];
  for (final raw in documents) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final lat = double.tryParse('${map['y'] ?? ''}');
    final lng = double.tryParse('${map['x'] ?? ''}');
    if (lat == null || lng == null) continue;
    final address = (map['address_name'] ?? '').toString().trim();
    String road = '';
    final roadRaw = map['road_address'];
    if (roadRaw is Map) {
      road = (roadRaw['address_name'] ?? '').toString().trim();
    }
    if (address.isEmpty && road.isEmpty) continue;
    out.add(
      KakaoPlaceHit(
        address: address.isNotEmpty ? address : road,
        roadAddress: road.isEmpty ? null : road,
        lat: lat,
        lng: lng,
      ),
    );
  }
  return out;
}

/// `교동 219-17` → `교동 219` 처럼 세부 번지를 빼 비슷한 지번을 더 찾는다.
String? kakaoBunjiRelaxedQuery(String query) {
  final q = query.trim();
  final m = RegExp(r'^(.+?)\s+(\d+)-(\d+)$').firstMatch(q);
  if (m == null) return null;
  final relaxed = '${m.group(1)} ${m.group(2)}';
  return relaxed == q ? null : relaxed;
}

/// `교동 219-17` → `교동`. 로/길 검색은 너무 넓어져서 제외.
String? kakaoAdminAreaQuery(String query) {
  final first = query.trim().split(RegExp(r'\s+')).first;
  if (first.length < 2) return null;
  if (!RegExp(r'(동|면|리|가|읍)$').hasMatch(first)) return null;
  return first == query.trim() ? null : first;
}

/// `교동`, `남양읍`처럼 행정구역 이름만 친 경우.
bool kakaoIsAdminAreaQuery(String query) {
  final t = query.trim();
  if (t.length < 2 || RegExp(r'\d').hasMatch(t)) return false;
  return RegExp(r'(동|면|리|가|읍)$').hasMatch(t);
}

List<KakaoPlaceHit> mergeKakaoHits(
  List<KakaoPlaceHit> keyword, [
  List<KakaoPlaceHit> address = const [],
  List<KakaoPlaceHit> extra = const [],
  List<KakaoPlaceHit> regions = const [],
]) {
  final seen = <String>{};
  final out = <KakaoPlaceHit>[];
  for (final hit in [...keyword, ...address, ...extra, ...regions]) {
    final key = hit.suggestionLabel;
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add(hit);
    if (out.length >= 40) break;
  }
  return out;
}

class KakaoLocalClient {
  KakaoLocalClient({http.Client? httpClient, String? restApiKey})
    : _http = httpClient ?? http.Client(),
      _restApiKey = restApiKey;

  final http.Client _http;
  final String? _restApiKey;

  String get _key => (_restApiKey ?? kakaoRestApiKey).trim();

  Future<List<KakaoPlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    if (_key.isEmpty) {
      throw StateError('카카오 API 키가 없습니다. 앱을 완전히 종료 후 다시 실행해 주세요.');
    }
    if (kakaoIsAdminAreaQuery(q)) {
      return mergeKakaoHits(await _fetchAddressPages(q));
    }
    final keyword = await _fetch(
      '/v2/local/search/keyword.json',
      q,
      parseKakaoKeywordDocuments,
    );
    final address = await _fetch(
      '/v2/local/search/address.json',
      q,
      parseKakaoAddressDocuments,
    );
    final relaxedQ = kakaoBunjiRelaxedQuery(q);
    final extra = relaxedQ == null
        ? const <KakaoPlaceHit>[]
        : await _fetch(
            '/v2/local/search/address.json',
            relaxedQ,
            parseKakaoAddressDocuments,
          );
    final areaQ = kakaoAdminAreaQuery(q);
    final regions = areaQ == null
        ? const <KakaoPlaceHit>[]
        : await _fetchAddressPages(areaQ);
    return mergeKakaoHits(keyword, address, extra, regions);
  }

  Future<List<KakaoPlaceHit>> _fetchAddressPages(String query) async {
    final page1 = await _fetch(
      '/v2/local/search/address.json',
      query,
      parseKakaoAddressDocuments,
    );
    if (page1.length < 15) return page1;
    final page2 = await _fetch(
      '/v2/local/search/address.json',
      query,
      parseKakaoAddressDocuments,
      page: 2,
    );
    return [...page1, ...page2];
  }

  Future<List<KakaoPlaceHit>> _fetch(
    String path,
    String query,
    List<KakaoPlaceHit> Function(List<dynamic>) parse, {
    int page = 1,
  }) async {
    final uri = Uri.https('dapi.kakao.com', path, {
      'query': query,
      'size': '15',
      'page': '$page',
    });
    final res = await _http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $_key'},
    );
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw StateError('카카오 주소 검색 키가 거부되었습니다.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) return const [];
    final body = jsonDecode(res.body);
    if (body is! Map) return const [];
    final docs = body['documents'];
    if (docs is! List) return const [];
    return parse(docs);
  }
}
