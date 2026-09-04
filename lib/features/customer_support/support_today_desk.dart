import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 홈·허브에서 오늘 바로 조치할 일.
enum SupportDeskItemKind {
  overdueVisit,
  todayPending,
  todayVisit,
  unsentQuote,
  overdueDeposit,
  todayDeposit,
}

int supportDeskItemPriority(SupportDeskItemKind kind) => switch (kind) {
  SupportDeskItemKind.overdueVisit => 0,
  SupportDeskItemKind.todayPending => 1,
  SupportDeskItemKind.todayVisit => 2,
  SupportDeskItemKind.unsentQuote => 3,
  SupportDeskItemKind.overdueDeposit => 4,
  SupportDeskItemKind.todayDeposit => 5,
};

class SupportDeskItem {
  const SupportDeskItem({
    required this.kind,
    required this.log,
    required this.reason,
    required this.actionLabel,
    required this.action,
    this.event,
  });

  final SupportDeskItemKind kind;
  final SupportCallLog log;
  final String reason;
  final String actionLabel;
  final SupportNextAction action;
  final SupportScheduleEvent? event;

  String get id => '${kind.name}:${log.id}:${event?.ymd ?? ''}';
}

class SupportTodayDesk {
  SupportTodayDesk({
    required this.todayYmd,
    required this.todayReception,
    required this.todayPending,
    required this.todayVisit,
    required this.overdueVisit,
    required this.unsentQuote,
    required this.todayDeposit,
    required this.overdueDeposit,
    this.feedbackWait = 0,
    this.verbalWait = 0,
    this.quoteSentWait = 0,
    required this.items,
  });

  final String todayYmd;
  final int todayReception;
  final int todayPending;
  final int todayVisit;
  final int overdueVisit;
  final int unsentQuote;
  final int todayDeposit;
  final int overdueDeposit;
  final int feedbackWait;
  final int verbalWait;
  final int quoteSentWait;
  final List<SupportDeskItem> items;

  static const previewLimit = 6;

  static final empty = SupportTodayDesk(
    todayYmd: '',
    todayReception: 0,
    todayPending: 0,
    todayVisit: 0,
    overdueVisit: 0,
    unsentQuote: 0,
    todayDeposit: 0,
    overdueDeposit: 0,
    feedbackWait: 0,
    verbalWait: 0,
    quoteSentWait: 0,
    items: [],
  );

  int get depositDue => todayDeposit + overdueDeposit;

  bool get hasAttention =>
      todayPending > 0 ||
      overdueVisit > 0 ||
      overdueDeposit > 0 ||
      unsentQuote > 0;

  bool get hasAny =>
      todayReception > 0 ||
      todayPending > 0 ||
      todayVisit > 0 ||
      overdueVisit > 0 ||
      unsentQuote > 0 ||
      depositDue > 0;

  List<SupportDeskItem> get preview =>
      items.length <= previewLimit ? items : items.sublist(0, previewLimit);

  bool get hasMore => items.length > previewLimit;

  int get moreCount =>
      items.length > previewLimit ? items.length - previewLimit : 0;
}

String supportDeskSiteTitle(SupportCallLog log) {
  final site = parseSupportIssueBody(log.issue).siteName.trim();
  if (site.isNotEmpty) return site;
  final name = log.customerName.trim();
  return name.isEmpty ? '(현장 없음)' : name;
}

String _visitReason(SupportScheduleEvent e, {required bool overdue}) {
  final time = (e.scheduledTime ?? e.log.visitTime ?? '').trim();
  final slot = time.length >= 5 ? time.substring(0, 5) : time;
  if (overdue) {
    return slot.isEmpty ? '지난 방문 ${e.ymd}' : '지난 방문 ${e.ymd} $slot';
  }
  return slot.isEmpty ? '오늘 방문' : '오늘 $slot';
}

String _quoteReason(SupportScheduleEvent e) {
  final day = e.ymd.trim();
  return day.isEmpty ? '견적 미발송' : '견적 미발송 · 발송예정 $day';
}

String _depositReason(SupportScheduleEvent e, {required bool overdue}) {
  final amount = e.amount;
  final won = amount == null || amount <= 0
      ? ''
      : ' ${formatSupportUnitPriceWon(amount)}';
  if (overdue) return '지난 입금 ${e.ymd}$won';
  return '오늘 입금$won';
}

bool _isOpenVisit(SupportScheduleEvent e) {
  if (e.kind != SupportScheduleKind.visit) return false;
  if (e.log.serviceStatusId == kSupportStatusCompleted) return false;
  return true;
}

/// [todayReceptions]는 오늘 접수된 건. [dueEvents]는 오늘까지의 방문/발송/입금.
SupportTodayDesk buildSupportTodayDesk({
  required String todayYmd,
  required List<SupportCallLog> todayReceptions,
  required List<SupportScheduleEvent> dueEvents,
  int feedbackWait = 0,
  int verbalWait = 0,
  int quoteSentWait = 0,
}) {
  final pending = todayReceptions.where((e) => e.isPending).toList();
  final items = <SupportDeskItem>[];
  final seen = <String>{};

  void add(SupportDeskItem item) {
    if (!seen.add(item.id)) return;
    items.add(item);
  }

  for (final log in pending) {
    add(
      SupportDeskItem(
        kind: SupportDeskItemKind.todayPending,
        log: log,
        reason: '오늘 접수 · 1차 상담 전',
        actionLabel: '상담',
        action: SupportNextAction.consult,
      ),
    );
  }

  var todayVisit = 0;
  var overdueVisit = 0;
  var unsentQuote = 0;
  var todayDeposit = 0;
  var overdueDeposit = 0;

  for (final e in dueEvents) {
    switch (e.kind) {
      case SupportScheduleKind.visit:
        if (!_isOpenVisit(e)) continue;
        final overdue = e.ymd.compareTo(todayYmd) < 0;
        if (overdue) {
          overdueVisit += 1;
        } else if (e.ymd == todayYmd) {
          todayVisit += 1;
        } else {
          continue;
        }
        add(
          SupportDeskItem(
            kind: overdue
                ? SupportDeskItemKind.overdueVisit
                : SupportDeskItemKind.todayVisit,
            log: e.log,
            reason: _visitReason(e, overdue: overdue),
            actionLabel: '방문 기록',
            action: SupportNextAction.visit,
            event: e,
          ),
        );
      case SupportScheduleKind.quoteSend:
        if (e.quoteSent) continue;
        if (e.ymd.compareTo(todayYmd) > 0) continue;
        unsentQuote += 1;
        add(
          SupportDeskItem(
            kind: SupportDeskItemKind.unsentQuote,
            log: e.log,
            reason: _quoteReason(e),
            actionLabel: '견적서',
            action: SupportNextAction.quote,
            event: e,
          ),
        );
      case SupportScheduleKind.deposit:
        if (e.depositPaid == true) continue;
        final overdue = e.ymd.compareTo(todayYmd) < 0;
        if (overdue) {
          overdueDeposit += 1;
        } else if (e.ymd == todayYmd) {
          todayDeposit += 1;
        } else {
          continue;
        }
        add(
          SupportDeskItem(
            kind: overdue
                ? SupportDeskItemKind.overdueDeposit
                : SupportDeskItemKind.todayDeposit,
            log: e.log,
            reason: _depositReason(e, overdue: overdue),
            actionLabel: '입금 확인',
            action: SupportNextAction.deposit,
            event: e,
          ),
        );
    }
  }

  items.sort((a, b) {
    final byKind = supportDeskItemPriority(
      a.kind,
    ).compareTo(supportDeskItemPriority(b.kind));
    if (byKind != 0) return byKind;
    return (a.event?.ymd ?? a.log.createdAt?.toIso8601String() ?? '').compareTo(
      b.event?.ymd ?? b.log.createdAt?.toIso8601String() ?? '',
    );
  });

  return SupportTodayDesk(
    todayYmd: todayYmd,
    todayReception: todayReceptions.length,
    todayPending: pending.length,
    todayVisit: todayVisit,
    overdueVisit: overdueVisit,
    unsentQuote: unsentQuote,
    todayDeposit: todayDeposit,
    overdueDeposit: overdueDeposit,
    feedbackWait: feedbackWait,
    verbalWait: verbalWait,
    quoteSentWait: quoteSentWait,
    items: items,
  );
}

final supportTodayDeskProvider = FutureProvider<SupportTodayDesk>((ref) async {
  final repo = ref.read(supportCallLogRepositoryProvider);
  final today = todayYmdSeoul();
  final events = await repo.listDueScheduleEvents(todayYmd: today);
  final todayReceptions = await repo.list(
    fromYmd: today,
    toYmdInclusive: today,
    limit: 400,
  );
  var feedbackWait = 0;
  var verbalWait = 0;
  var quoteSentWait = 0;
  try {
    final progress = await repo.list(
      statusId: kSupportStatusInProgress,
      limit: 400,
    );
    final snaps = await repo.lastConsultSnapshots(progress.map((e) => e.id));
    for (final s in snaps.values) {
      if (s.outcome == SupportConsultOutcome.feedbackWait) {
        feedbackWait += 1;
      } else if (s.outcome == SupportConsultOutcome.verbalQuote) {
        verbalWait += 1;
      } else if (s.outcome == SupportConsultOutcome.quoteSend &&
          (s.sentYmd ?? '').trim().isNotEmpty) {
        quoteSentWait += 1;
      }
    }
  } catch (_) {}
  return buildSupportTodayDesk(
    todayYmd: today,
    todayReceptions: todayReceptions,
    dueEvents: events,
    feedbackWait: feedbackWait,
    verbalWait: verbalWait,
    quoteSentWait: quoteSentWait,
  );
});
