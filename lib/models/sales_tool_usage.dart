import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 사용자 목록에서 명함·견적 작성자를 아이디·이름·직책 표기로 찾는다.
class SalesToolPerson {
  const SalesToolPerson({
    required this.id,
    required this.name,
    this.title = '',
    this.branch = '',
    this.isAdmin = false,
  });

  final String id;
  final String name;
  final String title;
  final String branch;
  final bool isAdmin;

  String get detail {
    final branchName = branch.trim();
    final job = title.trim();
    final parts = <String>[
      if (branchName.isNotEmpty) branchName,
      if (job.isNotEmpty && job != '팀원') job,
    ];
    return parts.join(' · ');
  }
}

class SalesToolDirectory {
  SalesToolDirectory(List<SalesToolPerson> people)
    : _people = List<SalesToolPerson>.unmodifiable(people),
      _byId = {
        for (final person in people)
          if (person.id.trim().isNotEmpty) person.id.trim(): person,
      },
      _byName = _groupByName(people);

  final List<SalesToolPerson> _people;
  final Map<String, SalesToolPerson> _byId;
  final Map<String, List<SalesToolPerson>> _byName;

  static Map<String, List<SalesToolPerson>> _groupByName(
    List<SalesToolPerson> people,
  ) {
    final map = <String, List<SalesToolPerson>>{};
    for (final person in people) {
      final name = person.name.trim();
      if (name.isEmpty) continue;
      map.putIfAbsent(name, () => []).add(person);
    }
    return map;
  }

  SalesToolPerson? resolve(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final byId = _byId[text];
    if (byId != null) return byId;
    final exact = _byName[text];
    if (exact != null && exact.length == 1) return exact.first;

    SalesToolPerson? best;
    var ties = 0;
    for (final person in _people) {
      final name = person.name.trim();
      if (name.isEmpty) continue;
      final hit = text == name || text.startsWith('$name ');
      if (!hit) continue;
      if (best == null || name.length > best.name.length) {
        best = person;
        ties = 1;
      } else if (name.length == best.name.length) {
        ties++;
      }
    }
    if (ties == 1) return best;
    return null;
  }

  /// 아이디, 이름, `이름 직책` 중 하나로 작성자를 맞춘다.
  ({String key, String name, String detail, bool isAdmin}) identify(
    String raw, {
    String fallbackName = '',
  }) {
    final person = resolve(raw) ?? resolve(fallbackName);
    if (person != null) {
      final name = person.name.trim().isEmpty ? raw.trim() : person.name.trim();
      return (
        key: person.id.trim().isEmpty ? 'name:$name' : person.id.trim(),
        name: name.isEmpty ? '알 수 없음' : name,
        detail: person.detail,
        isAdmin: person.isAdmin,
      );
    }
    final name = fallbackName.trim().isNotEmpty
        ? fallbackName.trim()
        : raw.trim();
    if (name.isEmpty) {
      return (key: 'unknown', name: '알 수 없음', detail: '', isAdmin: false);
    }
    return (key: 'name:$name', name: name, detail: '', isAdmin: false);
  }
}

SalesToolPerson? salesToolPersonFromUserRow(Map<String, dynamic> row) {
  final map = Map<String, dynamic>.from(row);
  final groups = map['groups'];
  if (groups is Map &&
      (map['groupName'] == null || '${map['groupName']}'.isEmpty)) {
    map['groupName'] = groups['name']?.toString();
  }
  final user = AppUser.fromJson(map);
  if (user.id.trim().isEmpty) return null;
  return SalesToolPerson(
    id: user.id.trim(),
    name: user.name.trim(),
    title: (user.title ?? '').trim(),
    branch: (user.branchName ?? '').trim(),
    isAdmin: isAppAdmin(user),
  );
}

class SalesToolEvent {
  const SalesToolEvent({
    required this.id,
    required this.actorKey,
    required this.actorName,
    required this.at,
    this.actorDetail = '',
    this.isAdmin = false,
    required this.title,
    this.subtitle = '',
    this.sent = false,
    this.amount = 0,
  });

  final String id;
  final String actorKey;
  final String actorName;
  final String actorDetail;
  final bool isAdmin;
  final DateTime at;
  final String title;
  final String subtitle;
  final bool sent;
  final int amount;
}

class SalesToolUserRank {
  const SalesToolUserRank({
    required this.actorKey,
    required this.userName,
    required this.count,
    required this.sentCount,
    required this.amountSum,
    this.lastAt,
    this.detail = '',
    this.isAdmin = false,
  });

  final String actorKey;
  final String userName;
  final int count;
  final int sentCount;
  final int amountSum;
  final DateTime? lastAt;
  final String detail;
  final bool isAdmin;
}

class SalesToolUsageReport {
  const SalesToolUsageReport({
    required this.ranks,
    required this.events,
    required this.totalCount,
    required this.sentCount,
    required this.amountSum,
  });

  final List<SalesToolUserRank> ranks;
  final List<SalesToolEvent> events;
  final int totalCount;
  final int sentCount;
  final int amountSum;

  int get userCount => ranks.length;

  SalesToolUserRank? get topUser => ranks.isEmpty ? null : ranks.first;

  List<SalesToolUserRank> get recentUsers {
    final copy = List<SalesToolUserRank>.from(ranks);
    copy.sort((a, b) {
      final at = (b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
      if (at != 0) return at;
      return a.userName.compareTo(b.userName);
    });
    return copy;
  }

  static const empty = SalesToolUsageReport(
    ranks: [],
    events: [],
    totalCount: 0,
    sentCount: 0,
    amountSum: 0,
  );
}

class SalesToolUsageBundle {
  const SalesToolUsageBundle({required this.cards, required this.quotes});

  final SalesToolUsageReport cards;
  final SalesToolUsageReport quotes;

  static const empty = SalesToolUsageBundle(
    cards: SalesToolUsageReport.empty,
    quotes: SalesToolUsageReport.empty,
  );
}

DateTime? parseSalesToolTimestamp(Object? raw) {
  if (raw is DateTime) return raw.toUtc();
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

int salesToolAmount(Object? raw) {
  if (raw is num) return raw.round();
  final text = (raw ?? '').toString().replaceAll(RegExp(r'[^0-9-]'), '');
  return int.tryParse(text) ?? 0;
}

SalesToolEvent? salesToolCardEvent(
  Map<String, dynamic> row,
  SalesToolDirectory directory,
) {
  final at = parseSalesToolTimestamp(row['created_at']);
  if (at == null) return null;
  final who = directory.identify(
    '${row['created_by'] ?? ''}',
    fallbackName: '${row['created_by_name'] ?? ''}',
  );
  final name = _text(row['name']);
  final company = _text(row['company']);
  return SalesToolEvent(
    id: '${row['id'] ?? ''}',
    actorKey: who.key,
    actorName: who.name,
    actorDetail: who.detail,
    isAdmin: who.isAdmin,
    at: at,
    title: name.isEmpty ? '이름 없음' : name,
    subtitle: company,
  );
}

SalesToolEvent? salesToolQuoteEvent(
  Map<String, dynamic> row,
  SalesToolDirectory directory,
) {
  final at = parseSalesToolTimestamp(row['created_at']);
  if (at == null) return null;
  final who = directory.identify('${row['created_by'] ?? ''}');
  final customer = _text(row['customer_name']);
  final site = _text(row['site']);
  final quoteNo = _text(row['quote_no']);
  final title = customer.isNotEmpty
      ? customer
      : site.isNotEmpty
      ? site
      : quoteNo.isNotEmpty
      ? quoteNo
      : '견적';
  final category = _text(row['category_name']);
  final model = _text(row['model_name']);
  final modelLabel = category.isNotEmpty && model.isNotEmpty
      ? '$category $model'
      : model.isNotEmpty
      ? model
      : category;
  final subtitle = [
    if (modelLabel.isNotEmpty) modelLabel,
    if (site.isNotEmpty && site != title) site,
  ].join(' · ');
  final sentYmd = _text(row['sent_ymd']);
  final emailYmd = _text(row['email_sent_ymd']);
  return SalesToolEvent(
    id: '${row['id'] ?? ''}',
    actorKey: who.key,
    actorName: who.name,
    actorDetail: who.detail,
    isAdmin: who.isAdmin,
    at: at,
    title: title,
    subtitle: subtitle,
    sent: sentYmd.isNotEmpty || emailYmd.isNotEmpty,
    amount: salesToolAmount(row['total']),
  );
}

/// 작성 건수 순. 같으면 발송, 금액, 이름 순.
SalesToolUsageReport buildSalesToolUsageReport(List<SalesToolEvent> events) {
  final byUser = <String, _SalesToolAcc>{};
  var sent = 0;
  var amount = 0;

  for (final event in events) {
    if (event.actorKey.isEmpty) continue;
    if (event.sent) sent++;
    amount += event.amount;
    final acc = byUser.putIfAbsent(
      event.actorKey,
      () => _SalesToolAcc(name: event.actorName),
    );
    if (acc.name.trim().isEmpty && event.actorName.trim().isNotEmpty) {
      acc.name = event.actorName.trim();
    }
    if (acc.detail.isEmpty && event.actorDetail.trim().isNotEmpty) {
      acc.detail = event.actorDetail.trim();
    }
    acc.count++;
    if (event.sent) acc.sentCount++;
    acc.amountSum += event.amount;
    acc.isAdmin = acc.isAdmin || event.isAdmin;
    if (acc.lastAt == null || event.at.isAfter(acc.lastAt!)) {
      acc.lastAt = event.at;
    }
  }

  final ranks =
      byUser.entries
          .map(
            (entry) => SalesToolUserRank(
              actorKey: entry.key,
              userName: entry.value.name.trim().isEmpty
                  ? '알 수 없음'
                  : entry.value.name.trim(),
              count: entry.value.count,
              sentCount: entry.value.sentCount,
              amountSum: entry.value.amountSum,
              lastAt: entry.value.lastAt,
              detail: entry.value.detail,
              isAdmin: entry.value.isAdmin,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          final bySent = b.sentCount.compareTo(a.sentCount);
          if (bySent != 0) return bySent;
          final byAmount = b.amountSum.compareTo(a.amountSum);
          if (byAmount != 0) return byAmount;
          return a.userName.compareTo(b.userName);
        });

  final sorted = List<SalesToolEvent>.from(events)
    ..sort((a, b) => b.at.compareTo(a.at));

  return SalesToolUsageReport(
    ranks: ranks,
    events: sorted,
    totalCount: events.where((event) => event.actorKey.isNotEmpty).length,
    sentCount: sent,
    amountSum: amount,
  );
}

String _text(Object? raw) => (raw ?? '').toString().trim();

class _SalesToolAcc {
  _SalesToolAcc({required this.name});

  String name;
  String detail = '';
  int count = 0;
  int sentCount = 0;
  int amountSum = 0;
  DateTime? lastAt;
  bool isAdmin = false;
}
