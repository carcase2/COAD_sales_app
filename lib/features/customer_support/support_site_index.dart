import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/models/region.dart';

class SupportIndexedSite {
  const SupportIndexedSite({
    required this.key,
    required this.title,
    required this.phone,
    required this.address,
    required this.assignee,
    required this.logs,
    this.quotes = const [],
  });

  final String key;
  final String title;
  final String phone;
  final String address;
  final String assignee;
  final List<SupportCallLog> logs;
  final List<SupportQuoteDocument> quotes;

  int get receptionCount => logs.length;

  bool get hasCompleted =>
      logs.any((l) => l.serviceStatusId == kSupportStatusCompleted);

  bool get allCompleted =>
      logs.isNotEmpty &&
      logs.every((l) => l.serviceStatusId == kSupportStatusCompleted);

  String get statusLabel {
    if (logs.isEmpty) return quotes.isEmpty ? '' : '견적만';
    if (allCompleted) return '완료';
    if (hasCompleted) return '완료 포함';
    if (logs.any((l) => l.isPending)) return '미처리';
    return '진행중';
  }

  SupportSiteSample toSiteSample() {
    final history = [
      ...logs.map(_logHistoryLine),
      ...quotes.map(supportQuoteHistoryLine),
    ];
    return SupportSiteSample(
      id: key,
      name: title,
      address: address,
      phone: phone,
      assignee: assignee,
      revisitCount: logs.length,
      installCompletedYmd: allCompleted ? _logYmd(logs.first) : null,
      addresses: {
        for (final log in logs)
          if ((log.address ?? '').trim().isNotEmpty) log.address!.trim(),
      }.toList(),
      history: history,
      quotes: quotes.map(supportQuoteHistoryLine).toList(),
      hasBusinessLicense: false,
      hasChecksheet: false,
    );
  }
}

String supportIndexedSiteKeyForLog(SupportCallLog log) {
  final phone = normalizePhoneDigits(log.customerPhone);
  if (phone.length >= 8) return 'p:$phone';
  final site = parseSupportIssueBody(log.issue).siteName.trim().toLowerCase();
  if (site.isNotEmpty) return 's:$site';
  final name = log.customerName.trim().toLowerCase();
  final addr = (log.address ?? '').trim().toLowerCase();
  if (name.isNotEmpty) return 'n:$name|$addr';
  return 'id:${log.id}';
}

String supportIndexedSiteKeyForQuote(SupportQuoteDocument doc) {
  final phone = normalizePhoneDigits(doc.phone);
  if (phone.length >= 8) return 'p:$phone';
  final site = doc.site.trim().toLowerCase();
  if (site.isNotEmpty) return 's:$site';
  final name = doc.customerName.trim().toLowerCase();
  if (name.isNotEmpty) return 'n:$name';
  return 'id:${doc.id}';
}

List<SupportIndexedSite> buildSupportIndexedSites({
  required List<SupportCallLog> logs,
  List<SupportQuoteDocument> quotes = const [],
}) {
  final logMap = <String, List<SupportCallLog>>{};
  for (final log in logs) {
    logMap.putIfAbsent(supportIndexedSiteKeyForLog(log), () => []).add(log);
  }
  final quoteMap = <String, List<SupportQuoteDocument>>{};
  for (final doc in quotes) {
    quoteMap.putIfAbsent(supportIndexedSiteKeyForQuote(doc), () => []).add(doc);
  }
  final keys = {...logMap.keys, ...quoteMap.keys};
  final sites = <SupportIndexedSite>[];
  for (final key in keys) {
    final siteLogs = [...(logMap[key] ?? const <SupportCallLog>[])]
      ..sort((a, b) {
        final at =
            a.createdAt ?? a.callDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt =
            b.createdAt ?? b.callDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    final siteQuotes = [...(quoteMap[key] ?? const <SupportQuoteDocument>[])]
      ..sort((a, b) => b.ymd.compareTo(a.ymd));
    sites.add(_siteFrom(key: key, logs: siteLogs, quotes: siteQuotes));
  }
  sites.sort((a, b) {
    final at = a.logs.isNotEmpty
        ? (a.logs.first.createdAt ?? a.logs.first.callDate)
        : null;
    final bt = b.logs.isNotEmpty
        ? (b.logs.first.createdAt ?? b.logs.first.callDate)
        : null;
    if (at == null && bt == null) return a.title.compareTo(b.title);
    if (at == null) return 1;
    if (bt == null) return -1;
    return bt.compareTo(at);
  });
  return sites;
}

String supportIndexedSiteBranch(SupportIndexedSite site, List<Region> regions) {
  final addresses = [site.address, ...site.logs.map((l) => l.address ?? '')];
  for (final addr in addresses) {
    if (addr.trim().isEmpty) continue;
    final branch = matchSupportBranchType(addr, regions);
    if (branch != '기타') return branch;
  }
  return matchSupportBranchType(site.address, regions);
}

bool supportIndexedSiteMatchesStatus(SupportIndexedSite site, String tab) {
  if (tab == '전체' || tab.trim().isEmpty) return true;
  if (site.logs.isEmpty) {
    return tab == '답 대기·견적서' && site.quotes.isNotEmpty;
  }
  return site.logs.any(
    (l) => supportCallLogProgressLabel(l.serviceStatusId) == tab,
  );
}

Map<String, int> supportIndexedSiteBranchCounts(
  Iterable<SupportIndexedSite> sites,
  List<Region> regions,
) {
  final counts = <String, int>{'전체': 0};
  for (final site in sites) {
    counts['전체'] = (counts['전체'] ?? 0) + 1;
    final branch = supportIndexedSiteBranch(site, regions);
    counts[branch] = (counts[branch] ?? 0) + 1;
  }
  return counts;
}

Map<String, int> supportIndexedSiteStatusCounts(
  Iterable<SupportIndexedSite> sites,
) {
  const tabs = ['미처리', '답 대기·견적서', '방문예정', '완료'];
  final counts = <String, int>{'전체': 0};
  for (final site in sites) {
    counts['전체'] = (counts['전체'] ?? 0) + 1;
    for (final tab in tabs) {
      if (supportIndexedSiteMatchesStatus(site, tab)) {
        counts[tab] = (counts[tab] ?? 0) + 1;
      }
    }
  }
  return counts;
}

bool supportIndexedSiteMatches(SupportIndexedSite site, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = normalizePhoneDigits(query);
  if (digits.length >= 4 && normalizePhoneDigits(site.phone).contains(digits)) {
    return true;
  }
  final blob = [
    site.title,
    site.phone,
    site.address,
    site.assignee,
    site.statusLabel,
    ...site.logs.map(
      (l) =>
          '${l.customerName} ${l.customerPhone} ${l.address ?? ''} ${l.issue} ${l.createdBy ?? ''}',
    ),
    ...site.quotes.map(
      (d) => '${d.customerName} ${d.site} ${d.quoteNo} ${d.workName}',
    ),
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

SupportIndexedSite _siteFrom({
  required String key,
  required List<SupportCallLog> logs,
  required List<SupportQuoteDocument> quotes,
}) {
  String pickLog(String Function(SupportCallLog log) of) {
    for (final log in logs) {
      final v = of(log).trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String pickQuote(String Function(SupportQuoteDocument doc) of) {
    for (final doc in quotes) {
      final v = of(doc).trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  final siteFromIssue = pickLog((l) => parseSupportIssueBody(l.issue).siteName);
  final title = siteFromIssue.isNotEmpty
      ? siteFromIssue
      : (pickLog((l) => l.customerName).isNotEmpty
            ? pickLog((l) => l.customerName)
            : (pickQuote((d) => d.site).isNotEmpty
                  ? pickQuote((d) => d.site)
                  : (pickQuote((d) => d.customerName).isNotEmpty
                        ? pickQuote((d) => d.customerName)
                        : '(현장 없음)')));
  return SupportIndexedSite(
    key: key,
    title: title,
    phone: pickLog((l) => l.customerPhone).isNotEmpty
        ? pickLog((l) => l.customerPhone)
        : pickQuote((d) => d.phone),
    address: pickLog((l) => l.address ?? '').isNotEmpty
        ? pickLog((l) => l.address ?? '')
        : pickQuote((d) => d.address),
    assignee: pickLog((l) => l.createdBy ?? ''),
    logs: logs,
    quotes: quotes,
  );
}

String _logYmd(SupportCallLog log) {
  final dt = log.createdAt ?? log.callDate;
  if (dt == null) return '';
  return ymdSeoulFromDateTime(dt);
}

String _logHistoryLine(SupportCallLog log) {
  final when = _logYmd(log);
  final status = supportCallLogProgressLabel(log.serviceStatusId);
  final parsed = parseSupportIssueBody(log.issue);
  final body = parsed.body.trim().replaceAll('\n', ' ');
  return [
    if (when.isNotEmpty) when,
    status,
    if (body.isNotEmpty) body,
  ].join(' · ');
}
