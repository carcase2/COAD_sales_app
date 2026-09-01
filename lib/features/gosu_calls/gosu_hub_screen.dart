import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/gosu_sales_calls_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_calendar_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_list_screen.dart';
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

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SupportHubTile(
                title: receptionLabel,
                subtitle: '해당 기간 접수',
                icon: Icons.today_rounded,
                count: counts.periodReception,
                onTap: () => _openList(
                  context,
                  mode: GosuListMode.dateRange,
                  title: receptionLabel,
                  fromYmd: range.$1,
                  toYmdInclusive: range.$2,
                ),
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
