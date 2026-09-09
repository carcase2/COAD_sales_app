import 'package:coad_customer_calls/models/install_after_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InstallAfterSearchLog log({
    required String id,
    required String userId,
    required String userName,
    required String action,
    String? model,
    String? query,
    DateTime? at,
  }) {
    return InstallAfterSearchLog(
      id: id,
      userId: userId,
      userName: userName,
      action: action,
      modelCode: model,
      query: query,
      createdAt: at ?? DateTime.utc(2026, 9, 9, 6),
    );
  }

  test('ranks users by search count', () {
    final report = buildInstallAfterUsageReport([
      log(id: '1', userId: 'a', userName: '김많이', action: 'search', model: 'C-50'),
      log(id: '2', userId: 'a', userName: '김많이', action: 'search', model: 'C-1'),
      log(id: '3', userId: 'a', userName: '김많이', action: 'view'),
      log(id: '4', userId: 'b', userName: '이조금', action: 'search', model: 'C-3'),
      log(id: '5', userId: 'b', userName: '이조금', action: 'download'),
    ], adminIds: {'b'});

    expect(report.totalSearches, 3);
    expect(report.totalViews, 1);
    expect(report.totalDownloads, 1);
    expect(report.topSearcher?.userName, '김많이');
    expect(report.topSearcher?.searches, 2);
    expect(report.ranks[1].userName, '이조금');
    expect(report.ranks[1].isAdmin, isTrue);
    expect(report.ranks.first.isAdmin, isFalse);
  });

  test('queryDisplay falls back for empty site search', () {
    final empty = log(
      id: '1',
      userId: 'a',
      userName: '홍',
      action: 'search',
    );
    expect(empty.queryDisplay, '현장명 없이 검색');
    expect(empty.modelDisplay, '모델 없음');
    expect(empty.actionLabel, '검색');
  });
}
