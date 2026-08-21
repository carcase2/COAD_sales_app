import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/data/business_card_ocr.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String id = 'u1',
  String role = 'user',
  String? groupName,
  List<String> permissions = const [],
}) => AppUser(
  id: id,
  name: '테스트',
  role: role,
  permissions: permissions,
  groupName: groupName,
);

BusinessCard _card({
  String createdBy = 'u1',
  BusinessCardVisibility visibility = BusinessCardVisibility.team,
}) => BusinessCard(
  id: 'c1',
  name: '홍길동',
  company: '코아드',
  title: '대표',
  mobilePhone: '010-1234-5678',
  officePhone: '02-111-2222',
  email: 'a@b.com',
  address: '서울',
  memo: '',
  imageUrl: '',
  visibility: visibility,
  createdBy: createdBy,
  createdByName: '작성자',
  updatedBy: createdBy,
  updatedByName: '작성자',
  createdAt: DateTime.utc(2026, 8, 19),
  updatedAt: DateTime.utc(2026, 8, 19),
);

void main() {
  test('canAccessBusinessCards — 레거시 빈 권한 허용', () {
    expect(canAccessBusinessCards(_user()), isTrue);
  });

  test('canAccessBusinessCards — 명시 권한', () {
    expect(
      canAccessBusinessCards(_user(permissions: ['business_cards'])),
      isTrue,
    );
    expect(canAccessBusinessCards(_user(permissions: ['sales_calls'])), isTrue);
    expect(canAccessBusinessCards(_user(permissions: ['quoter'])), isFalse);
    expect(canAccessBusinessCards(null), isFalse);
  });

  test('비공개 명함은 작성자·관리자만 열람', () {
    final private = _card(visibility: BusinessCardVisibility.private);
    expect(canViewBusinessCard(_user(id: 'u1'), private), isTrue);
    expect(canViewBusinessCard(_user(id: 'u2'), private), isFalse);
    expect(
      canViewBusinessCard(_user(id: 'u2', role: 'admin'), private),
      isTrue,
    );
  });

  test('팀 공유 명함은 로그인 사용자 열람, 수정은 작성자만', () {
    final team = _card();
    expect(canViewBusinessCard(_user(id: 'u2'), team), isTrue);
    expect(canEditBusinessCard(_user(id: 'u1'), team), isTrue);
    expect(canEditBusinessCard(_user(id: 'u2'), team), isFalse);
    expect(canEditBusinessCard(_user(id: 'u2', role: 'admin'), team), isTrue);
  });

  test('댓글은 작성자만 수정, 작성자·관리자 삭제', () {
    final comment = BusinessCardComment(
      id: 'n1',
      cardId: 'c1',
      body: '확인',
      createdBy: 'u1',
      createdByName: '작성자',
      createdAt: DateTime.utc(2026, 8, 19),
      updatedAt: DateTime.utc(2026, 8, 19),
    );
    expect(
      canEditBusinessCardComment(
        user: _user(id: 'u1'),
        comment: comment,
      ),
      isTrue,
    );
    expect(
      canEditBusinessCardComment(
        user: _user(id: 'u2'),
        comment: comment,
      ),
      isFalse,
    );
    expect(
      canDeleteBusinessCardComment(
        user: _user(id: 'u2', role: 'admin'),
        comment: comment,
      ),
      isTrue,
    );
  });

  test('BusinessCardResult — 휴대폰을 phone/mobile_phone에서 고름', () {
    final a = BusinessCardResult.fromJson({
      'name': '김영업',
      'company': '코아드',
      'title': '팀장',
      'mobile_phone': '010-1111-2222',
      'office_phone': '02-000-0000',
      'email': 'k@coad.com',
      'address': '대구',
    });
    expect(a.name, '김영업');
    expect(a.phone, '010-1111-2222');
    expect(a.officePhone, '02-000-0000');
    expect(a.title, '팀장');

    final b = BusinessCardResult.fromJson({
      'name': '이대표',
      'company': '테스트',
      'phone': '010-9999-0000',
    });
    expect(b.phone, '010-9999-0000');
  });

  test('displayName — 이름 없으면 회사', () {
    expect(_card().displayName, '홍길동');
    expect(_card().copyWith(name: '').displayName, '코아드');
    expect(_card().copyWith(name: '', company: '').displayName, '(이름 없음)');
  });

  test('parseBusinessCardText — 휴대폰·이메일·이름', () {
    final parsed = parseBusinessCardText('''
코아드
홍길동
대표이사
010-1234-5678
02-555-0000
hong@coad.co.kr
대구광역시 달서구 성서공단로
''');
    expect(parsed.name, '홍길동');
    expect(parsed.phone, '010-1234-5678');
    expect(parsed.email.toLowerCase(), 'hong@coad.co.kr');
    expect(parsed.hasAnyField, isTrue);
  });

  test('bestBusinessCardNameMatch — 완전 일치 우선', () {
    final hong = _card();
    final hongGil = _card().copyWith(id: 'c2', name: '홍길동팀장');
    expect(bestBusinessCardNameMatch('홍길동', [hongGil, hong])?.id, 'c1');
    expect(bestBusinessCardNameMatch('홍', [hong, hongGil]), isNull);
    expect(bestBusinessCardNameMatch('홍길동팀', [hongGil, hong])?.id, 'c2');
    expect(bestBusinessCardNameMatch('홍길', [hong])?.id, 'c1');
    expect(bestBusinessCardNameMatch('길동', [hong]), isNull);
  });

  test('같은 이름 명함은 휴대폰·사무실 번호를 나눠 고른다', () {
    final mobile = _card().copyWith(id: 'c1', officePhone: '');
    final both = _card().copyWith(
      id: 'c2',
      name: '홍길동',
      mobilePhone: '010-1111-2222',
      officePhone: '053-123-4567',
    );
    final choices = businessCardFillChoices('홍길동', [mobile, both]);
    expect(choices.length, 3);
    expect(choices.map((e) => e.phoneLabel).toSet(), {'휴대폰', '사무실'});
    expect(choices.where((e) => e.card.id == 'c2').length, 2);
  });

  test('번호가 하나면 선택 없이 바로 채운다', () {
    final one = _card().copyWith(officePhone: '', faxPhone: '');
    final choices = businessCardFillChoices('홍길동', [one]);
    expect(choices.length, 1);
    expect(choices.first.phoneLabel, '휴대폰');
    expect(choices.first.phone, '010-1234-5678');
  });
}
