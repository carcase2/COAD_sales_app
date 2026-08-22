import 'package:coad_customer_calls/features/mail/mail_helpers.dart';
import 'package:coad_customer_calls/features/mail/mail_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('최근 받는 사람은 성공 건만, 중복 없이', () {
    const rows = [
      MailSendRecord(
        id: '1',
        toEmail: 'a@coad.com',
        subject: 's',
        status: 'success',
        attachments: [MailAttachment(name: 'x.pdf', url: 'u')],
      ),
      MailSendRecord(
        id: '2',
        toEmail: 'A@coad.com',
        subject: 's',
        status: 'success',
      ),
      MailSendRecord(
        id: '3',
        toEmail: 'b@coad.com',
        subject: 's',
        status: 'failed',
      ),
      MailSendRecord(
        id: '4',
        toEmail: 'c@coad.com',
        subject: 's',
        status: 'success',
      ),
    ];
    final recent = uniqueRecentRecipients(rows);
    expect(recent.map((e) => e.email).toList(), ['a@coad.com', 'c@coad.com']);
  });

  test('첨부 파일은 URL 또는 이름으로 자료실과 맞춤', () {
    const files = [
      MailFile(
        id: '1',
        name: '카탈로그',
        originalName: 'catalog.pdf',
        url: 'https://x/a.pdf',
      ),
      MailFile(
        id: '2',
        name: '단가표',
        originalName: 'price.xlsx',
        url: 'https://x/b.xlsx',
      ),
    ];
    final ids = matchAttachmentFileIds(files, const [
      MailAttachment(name: 'other.pdf', url: 'https://x/a.pdf'),
      MailAttachment(name: 'price.xlsx', url: ''),
    ]);
    expect(ids, {'1', '2'});
  });

  test('이력 날짜 라벨', () {
    final now = DateTime(2026, 8, 22, 10);
    expect(mailHistoryDayLabel(DateTime(2026, 8, 22, 1), now), '오늘');
    expect(mailHistoryDayLabel(DateTime(2026, 8, 21, 23), now), '어제');
    expect(mailHistoryDayLabel(DateTime(2026, 8, 1), now), '8월 1일');
  });
}
