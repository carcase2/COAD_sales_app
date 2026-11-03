import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/data/business_card_vcard.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:flutter_test/flutter_test.dart';

BusinessCard _card({
  String name = '김철수',
  String company = '코드도어',
  String title = '팀장',
  String mobile = '010-1234-5678',
  String office = '',
  String fax = '',
  String email = '',
  String address = '',
}) => BusinessCard(
  id: '1',
  name: name,
  company: company,
  title: title,
  mobilePhone: mobile,
  officePhone: office,
  faxPhone: fax,
  email: email,
  address: address,
  memo: '',
  imageUrl: '',
  visibility: BusinessCardVisibility.team,
  createdBy: 'u',
  createdByName: '등록자',
  updatedBy: 'u',
  updatedByName: '등록자',
  createdAt: DateTime(2026, 11, 3),
  updatedAt: DateTime(2026, 11, 3),
);

void main() {
  test('명함 필드가 vCard 줄로 들어가고 CRLF로 끝난다', () {
    final v = businessCardVCard(
      _card(
        office: '02-123-4567',
        fax: '02-123-4568',
        email: 'kim.lee@gmail.com',
        address: '서울 강남구 테헤란로 1',
      ),
    );
    expect(v, startsWith('BEGIN:VCARD\r\nVERSION:3.0\r\n'));
    expect(v, contains('FN:김철수\r\n'));
    expect(v, contains('ORG:코드도어\r\n'));
    expect(v, contains('TITLE:팀장\r\n'));
    expect(v, contains('TEL;TYPE=CELL:010-1234-5678\r\n'));
    expect(v, contains('TEL;TYPE=WORK,VOICE:02-123-4567\r\n'));
    expect(v, contains('TEL;TYPE=WORK,FAX:02-123-4568\r\n'));
    expect(v, contains('EMAIL;TYPE=INTERNET:kim.lee@gmail.com\r\n'));
    expect(v, contains('ADR;TYPE=WORK:;;서울 강남구 테헤란로 1;;;;\r\n'));
    expect(v, endsWith('END:VCARD\r\n'));
  });

  test('빈 필드는 줄을 만들지 않는다', () {
    final v = businessCardVCard(_card(title: ''));
    expect(v, isNot(contains('TITLE:')));
    expect(v, isNot(contains('EMAIL')));
    expect(v, isNot(contains('ADR')));
    expect(v, isNot(contains('TYPE=FAX')));
  });

  test('이름이 없으면 회사명이 표시 이름이 된다', () {
    final v = businessCardVCard(_card(name: ''));
    expect(v, contains('FN:코드도어\r\n'));
    expect(businessCardVCardFileName(_card(name: '')), '코드도어.vcf');
  });

  test('쉼표·세미콜론·줄바꿈은 vCard 규칙대로 이스케이프한다', () {
    final v = businessCardVCard(
      _card(company: '코드, 도어;본사', address: '1층\n2호'),
    );
    expect(v, contains(r'ORG:코드\, 도어\;본사'));
    expect(v, contains(r'ADR;TYPE=WORK:;;1층\n2호;;;;'));
  });

  test('파일 이름에서 경로·공백 문자를 뺀다', () {
    expect(businessCardVCardFileName(_card(name: '김 철/수')), '김_철_수.vcf');
    expect(businessCardVCardFileName(_card(name: '', company: '')), '명함.vcf');
  });

  test('중복 안내는 이름과 같은 항목을 함께 보여준다', () {
    final d = BusinessCardDuplicate(card: _card(), reasons: ['휴대폰', '메일']);
    expect(d.label, '김철수 (휴대폰·메일 같음)');
  });
}
