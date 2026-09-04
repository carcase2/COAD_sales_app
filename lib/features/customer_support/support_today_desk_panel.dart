import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_hub_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_schedule_calendar_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_first_consultation_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_today_desk.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/features/home/home_hub_visual.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportTodayDeskCard extends StatelessWidget {
  const SupportTodayDeskCard({
    super.key,
    required this.desk,
    required this.onTapReception,
    required this.onTapVisit,
    required this.onTapDeposit,
    required this.onTapQuote,
    this.onTapFeedback,
    this.onTapVerbal,
    this.onTapQuoteSent,
    required this.onTapItem,
    required this.onTapAction,
    this.onTapPhone,
    this.onTapMore,
    this.headerAlert,
  });

  final SupportTodayDesk desk;
  final VoidCallback onTapReception;
  final VoidCallback onTapVisit;
  final VoidCallback onTapDeposit;
  final VoidCallback onTapQuote;
  final VoidCallback? onTapFeedback;
  final VoidCallback? onTapVerbal;
  final VoidCallback? onTapQuoteSent;
  final ValueChanged<SupportDeskItem> onTapItem;
  final ValueChanged<SupportDeskItem> onTapAction;
  final ValueChanged<SupportDeskItem>? onTapPhone;
  final VoidCallback? onTapMore;
  final Widget? headerAlert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    const gap = 8.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: HomeHubVisual.elevatedCard(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerAlert != null) ...[headerAlert!, SizedBox(height: gap)],
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DeskCountTile(
                    icon: Icons.inbox_rounded,
                    label: '접수',
                    count: desk.todayReception,
                    color: accent,
                    alert: desk.todayPending > 0,
                    badge: desk.todayPending > 0
                        ? '미처리 ${desk.todayPending}'
                        : null,
                    onTap: onTapReception,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _DeskCountTile(
                    icon: Icons.event_available_rounded,
                    label: '방문',
                    count: desk.todayVisit,
                    color: scheme.tertiary,
                    alert: desk.overdueVisit > 0,
                    badge: desk.overdueVisit > 0
                        ? '지난 ${desk.overdueVisit}'
                        : null,
                    onTap: onTapVisit,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _DeskCountTile(
                    icon: Icons.payments_outlined,
                    label: '수금',
                    count: desk.depositDue,
                    color: const Color(0xFF059669),
                    alert: desk.overdueDeposit > 0,
                    badge: desk.overdueDeposit > 0
                        ? '지난 ${desk.overdueDeposit}'
                        : null,
                    onTap: onTapDeposit,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _DeskCountTile(
                    icon: Icons.request_quote_outlined,
                    label: '미발송',
                    count: desk.unsentQuote,
                    color: const Color(0xFFD97706),
                    alert: desk.unsentQuote > 0,
                    onTap: onTapQuote,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desk.items.isEmpty ? '오늘 조치할 건이 없습니다' : '오늘 조치',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (desk.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '새 접수·방문·수금이 생기면 여기에 바로 나옵니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            for (final item in desk.preview) ...[
              _DeskActionRow(
                item: item,
                onTap: () => onTapItem(item),
                onAction: () => onTapAction(item),
                onPhone: onTapPhone == null ? null : () => onTapPhone!(item),
              ),
              const SizedBox(height: 4),
            ],
            if (desk.hasMore && onTapMore != null)
              TextButton(
                onPressed: onTapMore,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('더보기 ${desk.moreCount}건 · 보드'),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            '고객 대기',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _WaitTile(
                  label: '피드백',
                  count: desk.feedbackWait,
                  icon: Icons.phonelink_ring_rounded,
                  onTap: onTapFeedback,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _WaitTile(
                  label: '구두 견적',
                  count: desk.verbalWait,
                  icon: Icons.record_voice_over_outlined,
                  onTap: onTapVerbal,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _WaitTile(
                  label: '발송 후',
                  count: desk.quoteSentWait,
                  icon: Icons.mark_email_read_outlined,
                  onTap: onTapQuoteSent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeskCountTile extends StatelessWidget {
  const _DeskCountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.alert = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final bool alert;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = alert ? scheme.error : color;
    return Material(
      color: tone.withValues(alpha: alert ? 0.12 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: alert
              ? scheme.error.withValues(alpha: 0.35)
              : scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: tone),
                  const Spacer(),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: tone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: scheme.onSurface,
                ),
              ),
              if ((badge ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    badge!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitTile extends StatelessWidget {
  const _WaitTile({
    required this.label,
    required this.count,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final hot = count > 0;
    return Material(
      color: hot
          ? accent.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 12,
                    color: hot ? accent : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: hot ? accent : scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskActionRow extends StatelessWidget {
  const _DeskActionRow({
    required this.item,
    required this.onTap,
    required this.onAction,
    this.onPhone,
  });

  final SupportDeskItem item;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback? onPhone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phoneOk = looksLikePhoneQuery(item.log.customerPhone);
    final alert =
        item.kind == SupportDeskItemKind.overdueVisit ||
        item.kind == SupportDeskItemKind.overdueDeposit ||
        item.kind == SupportDeskItemKind.todayPending ||
        item.kind == SupportDeskItemKind.unsentQuote;
    final tone = alert ? scheme.error : AppTokens.customerSupportAccent(scheme);
    return Material(
      color: alert
          ? scheme.errorContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
          child: Row(
            children: [
              Icon(_kindIcon(item.kind), size: 17, color: tone),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supportDeskSiteTitle(item.log),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    Text(
                      item.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
              if (phoneOk && onPhone != null)
                IconButton(
                  tooltip: '전화',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: onPhone,
                  icon: Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction();
                },
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  item.actionLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _kindIcon(SupportDeskItemKind kind) => switch (kind) {
    SupportDeskItemKind.todayPending => Icons.phone_callback_rounded,
    SupportDeskItemKind.todayVisit => Icons.event_available_rounded,
    SupportDeskItemKind.overdueVisit => Icons.event_busy_rounded,
    SupportDeskItemKind.unsentQuote => Icons.request_quote_outlined,
    SupportDeskItemKind.todayDeposit => Icons.payments_outlined,
    SupportDeskItemKind.overdueDeposit => Icons.money_off_rounded,
  };
}

class SupportTodayDeskHost extends ConsumerWidget {
  const SupportTodayDeskHost({super.key, this.headerAlert});

  final Widget? headerAlert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(supportTodayDeskProvider);
    return async.when(
      data: (desk) => SupportTodayDeskCard(
        desk: desk,
        headerAlert: headerAlert,
        onTapReception: () => unawaited(_openReceptionToday(context, ref)),
        onTapVisit: () => unawaited(_openVisitCalendar(context, ref)),
        onTapDeposit: () => unawaited(_openCollection(context, ref)),
        onTapQuote: () => unawaited(_openUnsentQuotes(context, ref)),
        onTapFeedback: () => unawaited(_openWaitList(
          context,
          ref,
          title: '피드백 대기',
          outcome: SupportConsultOutcome.feedbackWait,
        )),
        onTapVerbal: () => unawaited(_openWaitList(
          context,
          ref,
          title: '구두 견적',
          outcome: SupportConsultOutcome.verbalQuote,
        )),
        onTapQuoteSent: () => unawaited(_openWaitList(
          context,
          ref,
          title: '발송 후 대기',
          outcome: SupportConsultOutcome.quoteSend,
          quoteSentOnly: true,
        )),
        onTapItem: (item) => unawaited(_openDetail(context, ref, item.log)),
        onTapAction: (item) => unawaited(_runAction(context, ref, item)),
        onTapPhone: (item) => unawaited(
          LauncherUtils.makePhoneCall(item.log.customerPhone),
        ),
        onTapMore: () => unawaited(_openHub(context, ref)),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SupportTodayDeskCard(
        desk: SupportTodayDesk.empty,
        headerAlert: headerAlert,
        onTapReception: () => unawaited(_openReceptionToday(context, ref)),
        onTapVisit: () => unawaited(_openVisitCalendar(context, ref)),
        onTapDeposit: () => unawaited(_openCollection(context, ref)),
        onTapQuote: () => unawaited(_openUnsentQuotes(context, ref)),
        onTapItem: (_) {},
        onTapAction: (_) {},
      ),
    );
  }
}

Future<void> _refresh(WidgetRef ref) async {
  invalidateSupportWorkCaches(ref);
  unawaited(refreshSupportDueReminders(ref));
}

Future<void> _openThenRefresh(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() open,
) async {
  await open();
  if (context.mounted) await _refresh(ref);
}

Future<void> _openHub(BuildContext context, WidgetRef ref) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerSupportHubScreen(),
      ),
    ),
  );
}

Future<void> _openReceptionToday(BuildContext context, WidgetRef ref) {
  final today = todayYmdSeoul();
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionListScreen(
          title: '오늘 접수',
          fromYmd: today,
          toYmdInclusive: today,
        ),
      ),
    ),
  );
}

Future<void> _openVisitCalendar(BuildContext context, WidgetRef ref) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportScheduleCalendarScreen(
          initialKind: SupportScheduleKind.visit,
          initialYmd: todayYmdSeoul(),
        ),
      ),
    ),
  );
}

Future<void> _openCollection(BuildContext context, WidgetRef ref) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerSupportCollectionScreen(
          initialFilter: 'due',
        ),
      ),
    ),
  );
}

Future<void> _openWaitList(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required SupportConsultOutcome outcome,
  bool quoteSentOnly = false,
}) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionListScreen(
          title: title,
          consultOutcome: outcome,
          quoteSentOnly: quoteSentOnly,
        ),
      ),
    ),
  );
}

Future<void> _openUnsentQuotes(BuildContext context, WidgetRef ref) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportScheduleCalendarScreen(
          initialKind: SupportScheduleKind.quoteSend,
          initialYmd: todayYmdSeoul(),
        ),
      ),
    ),
  );
}

Future<void> _openDetail(
  BuildContext context,
  WidgetRef ref,
  SupportCallLog log,
) {
  return _openThenRefresh(
    context,
    ref,
    () => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSupportReceptionDetailScreen(log: log),
      ),
    ),
  );
}

Future<void> _runAction(
  BuildContext context,
  WidgetRef ref,
  SupportDeskItem item,
) async {
  try {
    switch (item.action) {
      case SupportNextAction.consult:
        final saved = await showSupportFirstConsultationSheet(
          context,
          log: item.log,
        );
        if (saved && context.mounted) await _refresh(ref);
      case SupportNextAction.visit:
        final saved = await showSupportVisitReportSheet(
          context,
          log: item.log,
        );
        if (saved && context.mounted) await _refresh(ref);
      case SupportNextAction.quote:
        final log = item.log;
        await pushSupportQuoteEditor(
          context,
          callLogId: log.id,
          site: SupportSiteSample(
            id: log.id,
            name: log.customerName.trim(),
            address: log.address ?? '',
            phone: log.customerPhone,
            assignee: log.createdBy ?? '',
            revisitCount: 0,
            installCompletedYmd: null,
            addresses: [
              if ((log.address ?? '').trim().isNotEmpty) log.address!.trim(),
            ],
            history: const [],
            quotes: const [],
            hasBusinessLicense: false,
            hasChecksheet: false,
          ),
        );
        if (context.mounted) await _refresh(ref);
      case SupportNextAction.deposit:
        final report = item.event?.visitReport;
        if (report == null || (report.id ?? '').isEmpty) {
          await _openCollection(context, ref);
          return;
        }
        final next = await nextSupportDepositPaidReport(
          context,
          report: report,
          currentlyPaid: false,
          plannedYmd: report.depositYmd ?? item.event?.ymd,
        );
        if (next == null || !context.mounted) return;
        await ref.read(supportCallLogRepositoryProvider).updateVisitReport(next);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('입금을 확인했습니다.')));
          await _refresh(ref);
        }
      case SupportNextAction.done:
        await _openDetail(context, ref, item.log);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
  }
}
