import 'package:coad_customer_calls/data/kakao_local_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseKakaoKeywordDocuments — 도로명·장소명', () {
    final hits = parseKakaoKeywordDocuments([
      {
        'place_name': '코아드',
        'address_name': '대구 달서구 성서공단로 11',
        'road_address_name': '대구 달서구 성서공단로 99',
        'y': '35.85',
        'x': '128.50',
      },
    ]);
    expect(hits, hasLength(1));
    expect(hits.first.displayAddress, '대구 달서구 성서공단로 99');
    expect(hits.first.suggestionLabel, '대구 달서구 성서공단로 99 코아드');
    expect(hits.first.placeName, '코아드');
    expect(hits.first.lat, 35.85);
    expect(hits.first.lng, 128.50);
  });

  test('parseKakaoAddressDocuments — road_address 객체', () {
    final hits = parseKakaoAddressDocuments([
      {
        'address_name': '서울 강남구 역삼동 123',
        'road_address': {'address_name': '서울 강남구 테헤란로 12'},
        'y': '37.5',
        'x': '127.0',
      },
    ]);
    expect(hits.single.displayAddress, '서울 강남구 테헤란로 12');
  });

  test('mergeKakaoHits — 같은 표시 주소는 한 번만', () {
    const a = KakaoPlaceHit(
      address: '서울 강남구 테헤란로 12',
      roadAddress: '서울 강남구 테헤란로 12',
      lat: 1,
      lng: 2,
    );
    const b = KakaoPlaceHit(address: '서울 강남구 테헤란로 12', lat: 1, lng: 2);
    const c = KakaoPlaceHit(address: '서울 강남구 역삼로 1', lat: 3, lng: 4);
    expect(mergeKakaoHits([a], [b, c]), hasLength(2));
  });

  test('mergeKakaoHits — 같은 도로여도 상호가 다르면 따로', () {
    const shop = KakaoPlaceHit(
      address: '울산 중구 교동 219-17',
      roadAddress: '울산 중구 명륜로 133-1',
      placeName: '신광기획',
      lat: 1,
      lng: 2,
    );
    const other = KakaoPlaceHit(
      address: '울산 중구 교동 219-17',
      roadAddress: '울산 중구 명륜로 133-1',
      placeName: '태화강예술단',
      lat: 1,
      lng: 2,
    );
    const lot = KakaoPlaceHit(
      address: '울산 중구 교동 219-17',
      roadAddress: '울산 중구 명륜로 133-1',
      lat: 1,
      lng: 2,
    );
    expect(mergeKakaoHits([shop, other], [lot]), hasLength(3));
  });

  test('kakaoBunjiRelaxedQuery — 교동 219-17 → 교동 219', () {
    expect(kakaoBunjiRelaxedQuery('교동 219-17'), '교동 219');
    expect(kakaoBunjiRelaxedQuery('현대기아로 202-37'), '현대기아로 202');
    expect(kakaoBunjiRelaxedQuery('교동'), isNull);
  });

  test('kakaoAdminAreaQuery — 동/면만 추출', () {
    expect(kakaoAdminAreaQuery('교동 219-17'), '교동');
    expect(kakaoAdminAreaQuery('현대기아로 202-37'), isNull);
    expect(kakaoAdminAreaQuery('교동'), isNull);
  });

  test('kakaoIsAdminAreaQuery — 교동만 치면 행정구역 목록', () {
    expect(kakaoIsAdminAreaQuery('교동'), isTrue);
    expect(kakaoIsAdminAreaQuery('남양읍'), isTrue);
    expect(kakaoIsAdminAreaQuery('교동 219-17'), isFalse);
    expect(kakaoIsAdminAreaQuery('현대기아로'), isFalse);
  });

  test('suggestionLabel — 도로명 뒤에 상호', () {
    const hit = KakaoPlaceHit(
      address: '경기 화성시 남양읍 남양리 1',
      roadAddress: '경기 화성시 남양읍 현대기아로 202-37',
      placeName: '코아드',
      lat: 37.2,
      lng: 126.8,
    );
    expect(hit.suggestionLabel, '경기 화성시 남양읍 현대기아로 202-37 코아드');
  });
}
