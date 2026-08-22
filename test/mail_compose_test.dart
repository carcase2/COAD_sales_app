import 'package:coad_customer_calls/features/mail/mail_compose.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('이메일 형식', () {
    expect(MailCompose.isValidEmail('a@b.com'), isTrue);
    expect(MailCompose.isValidEmail('  sales@coaddoor.com '), isTrue);
    expect(MailCompose.isValidEmail(''), isFalse);
    expect(MailCompose.isValidEmail('not-an-email'), isFalse);
  });

  test('제목은 담당자 이름', () {
    expect(MailCompose.subject(senderName: '김경덕'), '[COAD] 김경덕 - 선택된 파일 발송');
    expect(MailCompose.subject(senderName: '  '), '[COAD] 관리자 - 선택된 파일 발송');
  });

  test('본문에 연락처와 첨부 파일명', () {
    final text = MailCompose.body(
      senderName: '홍길동',
      phone: '010-1234-5678',
      email: 'hong@coad.co.kr',
      attachmentNames: const ['카탈로그.pdf', '단가표.xlsx'],
    );
    expect(text, contains('코아드의 홍길동입니다'));
    expect(text, contains('010-1234-5678'));
    expect(text, contains('hong@coad.co.kr'));
    expect(text, contains('카탈로그.pdf'));
    expect(text, contains('단가표.xlsx'));
  });

  test('텔레그램 담당자 이름 매칭', () {
    expect(MailCompose.resolveTelegramAgentName('김경덕', ['김경덕', '홍길동']), '김경덕');
    expect(MailCompose.resolveTelegramAgentName('kim', ['KIM']), 'KIM');
    expect(MailCompose.resolveTelegramAgentName('없는사람', ['김경덕']), '');
  });

  test('파일 분류 그룹 — 미분류는 맨 뒤', () {
    final groups = MailFileGroup.from(
      files: const [
        MailFile(
          id: '1',
          name: 'A',
          originalName: 'a.pdf',
          url: 'u',
          categoryId: 'c1',
        ),
        MailFile(id: '2', name: 'B', originalName: 'b.pdf', url: 'u'),
      ],
      categories: const [
        MailCategory(id: 'c1', name: '카탈로그', colorHex: '#3b82f6'),
      ],
    );
    expect(groups.map((e) => e.name).toList(), ['카탈로그', '미분류']);
    expect(groups.first.items.single.name, 'A');
  });
}
