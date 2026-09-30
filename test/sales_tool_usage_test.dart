import 'package:coad_customer_calls/models/sales_tool_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SalesToolDirectory directory() {
    return SalesToolDirectory(const [
      SalesToolPerson(id: 'kim', name: '김인엽', title: '이사', branch: '본사'),
      SalesToolPerson(
        id: 'park',
        name: '박정훈',
        title: '상무',
        branch: '본사',
        isAdmin: true,
      ),
      SalesToolPerson(id: 'lee-a', name: '이상수', title: '팀장', branch: '본사'),
      SalesToolPerson(id: 'lee-b', name: '이상수', title: '팀장', branch: '대구지사'),
    ]);
  }

  test('matches quote author by name and title', () {
    final who = directory().identify('김인엽 이사');
    expect(who.key, 'kim');
    expect(who.name, '김인엽');
    expect(who.detail, '본사 · 이사');
    expect(who.isAdmin, isFalse);
  });

  test('matches card author by user id and keeps admin', () {
    final event = salesToolCardEvent({
      'id': 'c1',
      'name': '홍길동',
      'company': '코아드',
      'created_by': 'park',
      'created_by_name': '박정훈',
      'created_at': '2026-09-30T01:00:00Z',
    }, directory());
    expect(event?.actorKey, 'park');
    expect(event?.actorName, '박정훈');
    expect(event?.isAdmin, isTrue);
    expect(event?.title, '홍길동');
    expect(event?.subtitle, '코아드');
  });

  test('ambiguous same name stays as written', () {
    final who = directory().identify('이상수 팀장');
    expect(who.key, 'name:이상수 팀장');
    expect(who.name, '이상수 팀장');
  });

  test('ranks by count then sent, and recent users by time', () {
    final dir = directory();
    final report = buildSalesToolUsageReport([
      salesToolQuoteEvent({
        'id': 'q1',
        'customer_name': '에이공장',
        'site': '화성',
        'category_name': '스피드도어',
        'model_name': 'PREMIUM',
        'total': 1000000,
        'sent_ymd': '2026-09-28',
        'created_by': '김인엽 이사',
        'created_at': '2026-09-28T01:00:00Z',
      }, dir)!,
      salesToolQuoteEvent({
        'id': 'q2',
        'customer_name': '비공장',
        'site': '평택',
        'model_name': 'STANDARD',
        'total': 500000,
        'created_by': '김인엽 이사',
        'created_at': '2026-09-29T01:00:00Z',
      }, dir)!,
      salesToolQuoteEvent({
        'id': 'q3',
        'customer_name': '씨공장',
        'site': '대구',
        'total': 2000000,
        'email_sent_ymd': '2026-09-30',
        'created_by': 'park',
        'created_at': '2026-09-30T03:00:00Z',
      }, dir)!,
    ]);

    expect(report.totalCount, 3);
    expect(report.sentCount, 2);
    expect(report.amountSum, 3500000);
    expect(report.topUser?.userName, '김인엽');
    expect(report.topUser?.count, 2);
    expect(report.topUser?.sentCount, 1);
    expect(report.ranks[1].userName, '박정훈');
    expect(report.ranks[1].isAdmin, isTrue);
    expect(report.recentUsers.first.userName, '박정훈');
    expect(report.events.first.title, '씨공장');
    expect(report.events.first.subtitle, '대구');
    expect(report.events.first.sent, isTrue);
  });

  test('quote without customer uses site and model', () {
    final event = salesToolQuoteEvent({
      'id': 'q',
      'site': '나주',
      'category_name': '셔터',
      'model_name': '내풍압',
      'total': '1200000',
      'created_by': '',
      'created_at': '2026-09-01T00:00:00+09:00',
    }, SalesToolDirectory(const []));
    expect(event?.title, '나주');
    expect(event?.subtitle, '셔터 내풍압');
    expect(event?.actorName, '알 수 없음');
    expect(event?.amount, 1200000);
  });

  test('user row marks admin group and branch', () {
    final person = salesToolPersonFromUserRow({
      'id': 'admin-1',
      'name': '관리자',
      'title': '팀장',
      'role': 'user',
      'groups': {'name': '관리자'},
      'coad_branch': {'name': '본사'},
    });
    expect(person?.isAdmin, isTrue);
    expect(person?.detail, '본사 · 팀장');
  });
}
