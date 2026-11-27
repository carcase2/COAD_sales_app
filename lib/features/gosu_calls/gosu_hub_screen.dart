import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/gosu_sales_calls_repository.dart';
import 'package:coad_customer_calls/data/gosu_sites_repository.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_combined_reception_screen.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_list_screen.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_visit_calendar_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_calendar_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_list_screen.dart';
import 'package:coad_customer_calls/features/home/gosu_today_desk.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GosuHubScreen extends ConsumerWidget {
  const GosuHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    if (user == null || !canAccessGosuCalls(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('자동문의고수')),
        body: const AppEmpty(
          icon: Icons.lock_outline_rounded,
          message: '자동문의고수 메뉴 접근 권한이 없습니다.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('자동문의고수')),
      body: const GosuHomePanel(embedded: false),
    );
  }
}

class GosuHomePanel extends ConsumerWidget {
  const GosuHomePanel({
    super.key,
    required this.embedded,
    this.periodKey,
    this.receptionLabel = '금일 접수',
    this.updatedLabel = '금일 업데이트',
    this.followLabel = '금일 팔로우',
  });

  final bool embedded;
  final HubPeriodKey? periodKey;
  final String receptionLabel;
  final String updatedLabel;
  final String followLabel;

  HubPeriodKey get _key =>
      periodKey ?? (period: HubPeriod.day, anchorYmd: todayYmdSeoul());

  Future<void> _openList(
    BuildContext context, {
    required GosuListMode mode,
    required String title,
    String? fromYmd,
    String? toYmdInclusive,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GosuCallListScreen(
          mode: mode,
          title: title,
          fromYmd: fromYmd,
          toYmdInclusive: toYmdInclusive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(gosuHomeCountsProvider(_key)).valueOrNull ??
        GosuHomeCounts.empty;
    final range = switch (_key.period) {
      HubPeriod.day => (_key.anchorYmd, _key.anchorYmd),
      HubPeriod.week => seoulWeekRangeContaining(_key.anchorYmd),
      HubPeriod.month => seoulMonthRangeContaining(_key.anchorYmd),
    };
    // 금일 접수 = 전화 접수(gosu_sales_calls) + 홈페이지 문의(gosu_sites)
    final siteCount =
        ref.watch(gosuSiteReceivedCountProvider(range)).valueOrNull ?? 0;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SupportHubTile(
                title: receptionLabel,
                subtitle: '전화 ${counts.periodReception} · 홈페이지 $siteCount',
                icon: Icons.today_rounded,
                count: counts.periodReception + siteCount,
                onTap: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute<void>(
                        builder: (_) => GosuCombinedReceptionScreen(
                          title: receptionLabel,
                          fromYmd: range.$1,
                          toYmdInclusive: range.$2,
                        ),
                      ),
                    )
                    .then((_) => ref.invalidate(gosuSiteReceivedCountProvider)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SupportHubTile(
                title: updatedLabel,
                subtitle: '해당 기간 업데이트',
                icon: Icons.update_rounded,
                count: counts.periodUpdated,
                onTap: () => _openList(
                  context,
                  mode: GosuListMode.updatedRange,
                  title: updatedLabel,
                  fromYmd: range.$1,
                  toYmdInclusive: range.$2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SupportHubTile(
                title: '팔로업중',
                subtitle: '종료 전',
                icon: Icons.phone_callback_rounded,
                count: counts.awaitingFollowUp,
                alert: counts.awaitingFollowUp > 0,
                onTap: () => _openList(
                  context,
                  mode: GosuListMode.awaitingFollowUp,
                  title: '팔로업중',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SupportHubTile(
                title: followLabel,
                subtitle: '예정일 기준',
                icon: Icons.event_available_rounded,
                count: counts.periodFollow,
                alert: counts.periodFollow > 0,
                onTap: () => _openList(
                  context,
                  mode: GosuListMode.followRange,
                  title: followLabel,
                  fromYmd: range.$1,
                  toYmdInclusive: range.$2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const GosuSiteHomeSection(),
        if (_key.period == HubPeriod.day) ...[
          const SizedBox(height: 12),
          const GosuTodayDeskHost(),
        ],
        const SizedBox(height: 12),
        SupportSectionCard(
          title: '전체',
          subtitle:
              '팔로업중 ${counts.awaitingFollowUp} · 종료 ${counts.closedCount}',
          icon: Icons.list_alt_rounded,
          badge: '${counts.allCount}',
          onTap: () => _openList(context, mode: GosuListMode.all, title: '전체'),
        ),
        const SizedBox(height: 8),
        SupportSectionCard(
          title: '기존진행중',
          subtitle: '1차 이후 미종료 ${counts.activeFollowUp}건',
          icon: Icons.timelapse_rounded,
          onTap: () => _openList(
            context,
            mode: GosuListMode.activeFollowUp,
            title: '기존진행중',
          ),
        ),
        const SizedBox(height: 8),
        SupportSectionCard(
          title: '팔로업 달력',
          subtitle: '예정일 ${counts.scheduled}건',
          icon: Icons.calendar_month_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GosuCalendarScreen()),
          ),
        ),
      ],
    );

    if (embedded) return body;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [body],
    );
  }
}

/// 고수 사이트 홈페이지 문의 (coad-gosu-followup 동기화) — 오늘 접수 · 접수중 · 취소 사유 · 방문 달력.
class GosuSiteHomeSection extends ConsumerWidget {
  const GosuSiteHomeSection({super.key});

  void _push(BuildContext context, WidgetRef ref, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen))
        .then((_) => ref.invalidate(gosuSiteCountsProvider));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(gosuSiteCountsProvider).valueOrNull ?? GosuSiteCounts.empty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            '홈페이지 문의 (고수 사이트)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SupportHubTile(
                title: '오늘 접수',
                subtitle: counts.today == 0
                    ? '홈페이지'
                    : '접수중 ${counts.todayReceiving} · 완료 ${counts.todayAccepted}',
                alert: counts.todayReceiving > 0,
                icon: Icons.language_rounded,
                count: counts.today,
                onTap: () => _push(
                  context,
                  ref,
                  const GosuSiteListScreen(initialTab: GosuSiteTab.today),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SupportHubTile(
                title: '접수중',
                subtitle: counts.stale > 0 ? '지연 ${counts.stale}건' : '통화 기록',
                icon: Icons.phone_in_talk_rounded,
                count: counts.receiving,
                alert: counts.stale > 0,
                onTap: () => _push(
                  context,
                  ref,
                  const GosuSiteListScreen(initialTab: GosuSiteTab.receiving),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SupportSectionCard(
          title: '접수취소 사유',
          subtitle: counts.cancelNoReason > 0
              ? '최근 30일 · 사유 미기록 ${counts.cancelNoReason}건'
              : '최근 30일 접수취소',
          icon: Icons.cancel_outlined,
          badge: counts.cancelNoReason > 0 ? '${counts.cancelNoReason}' : null,
          onTap: () => _push(
            context,
            ref,
            const GosuSiteListScreen(initialTab: GosuSiteTab.cancel),
          ),
        ),
        const SizedBox(height: 8),
        SupportSectionCard(
          title: '방문 달력',
          subtitle: '고수에 입력된 방문예정일',
          icon: Icons.event_note_rounded,
          onTap: () => _push(context, ref, const GosuSiteVisitCalendarScreen()),
        ),
      ],
    );
  }
}
