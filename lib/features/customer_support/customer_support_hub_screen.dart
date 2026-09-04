import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_completion_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_faq_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_schedule_calendar_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_site_search_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/reception_create_host_screen.dart';
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_sites_map_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_teams_screen.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_hub_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerSupportHubScreen extends ConsumerWidget {
  const CustomerSupportHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    if (user == null || !canAccessCustomerSupport(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('고객지원팀')),
        body: const AppEmpty(
          icon: Icons.lock_outline_rounded,
          message: '고객지원팀 메뉴 접근 권한이 없습니다.',
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final desk =
        ref.watch(supportDeskCountsProvider).valueOrNull ??
        SupportDeskCounts.empty;

    Future<void> openThenRefresh(Future<void> Function() open) async {
      await open();
      if (context.mounted) invalidateSupportWorkCaches(ref);
    }

    final today = todayYmdSeoul();

    return Scaffold(
      appBar: AppBar(
        title: const Text('고객지원팀'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () => invalidateSupportWorkCaches(ref),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _BoardHeader(accent: accent, scheme: scheme),
          if (desk.hasAttention) ...[
            const SizedBox(height: 12),
            Material(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                leading: Icon(
                  Icons.notification_important_outlined,
                  color: scheme.onErrorContainer,
                ),
                title: Text(
                  [
                    if (desk.todayPending > 0) '오늘 미처리 ${desk.todayPending}',
                    if (desk.pending > 0) '미처리 ${desk.pending}',
                    if (desk.unsentQuote > 0) '견적 미발송 ${desk.unsentQuote}',
                    if (desk.overdueVisit > 0) '지난 방문 ${desk.overdueVisit}',
                    if (desk.overdueDeposit > 0) '지난 입금 ${desk.overdueDeposit}',
                  ].join(' · '),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  '접수·견적·방문·수금을 먼저 챙기세요.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '지금 할 일',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SupportHubCountBar(
            title: '접수 · 미처리',
            icon: Icons.phone_callback_rounded,
            count: desk.pending,
            alert: desk.pending > 0,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const CustomerSupportReceptionListScreen(
                  title: '접수 · 미처리',
                  pendingOnly: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportHubCountBar(
            title: '대기',
            icon: Icons.timelapse_rounded,
            count: desk.inProgress,
            alert: desk.inProgress > 0,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const CustomerSupportReceptionListScreen(
                  title: '대기',
                  statusId: kSupportStatusInProgress,
                  initialStatusTab: '대기',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _HubTileRow(
            left: SupportHubTile(
              title: '피드백',
              subtitle: '안내 후 고객 연락 대기',
              icon: Icons.phonelink_ring_rounded,
              count: desk.feedbackWait,
              alert: desk.feedbackWait > 0,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  const CustomerSupportReceptionListScreen(
                    title: '피드백 대기',
                    consultOutcome: SupportConsultOutcome.feedbackWait,
                  ),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '구두 견적',
              subtitle: '말로 금액 전달 · 재연락',
              icon: Icons.record_voice_over_outlined,
              count: desk.verbalWait,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  const CustomerSupportReceptionListScreen(
                    title: '구두 견적',
                    consultOutcome: SupportConsultOutcome.verbalQuote,
                  ),
                ),
              ),
            ),
          ),
          _HubTileRow(
            left: SupportHubTile(
              title: '견적 미발송',
              subtitle: '작성·보낼 날 체크',
              icon: Icons.request_quote_outlined,
              count: desk.unsentQuote,
              alert: desk.unsentQuote > 0,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  CustomerSupportScheduleCalendarScreen(
                    initialKind: SupportScheduleKind.quoteSend,
                    initialYmd: today,
                  ),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '발송 후 대기',
              subtitle: '정식 견적 보냄 · 고객 답',
              icon: Icons.mark_email_read_outlined,
              count: desk.quoteSentWait,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  const CustomerSupportReceptionListScreen(
                    title: '발송 후 대기',
                    consultOutcome: SupportConsultOutcome.quoteSend,
                    quoteSentOnly: true,
                  ),
                ),
              ),
            ),
          ),
          _HubTileRow(
            left: SupportHubTile(
              title: '오늘 방문',
              subtitle: '오늘 가기로 한 현장',
              icon: Icons.event_available_rounded,
              count: desk.todayVisit,
              alert: desk.todayVisit > 0,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  CustomerSupportScheduleCalendarScreen(
                    initialKind: SupportScheduleKind.visit,
                    initialYmd: today,
                  ),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '지난 방문',
              subtitle: '기록 안 남긴 방문',
              icon: Icons.event_busy_rounded,
              count: desk.overdueVisit,
              alert: desk.overdueVisit > 0,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  CustomerSupportScheduleCalendarScreen(
                    initialKind: SupportScheduleKind.visit,
                    initialYmd: today,
                  ),
                ),
              ),
            ),
          ),
          _HubTileRow(
            left: SupportHubTile(
              title: '오늘 입금',
              subtitle: '유상 입금 확인',
              icon: Icons.payments_outlined,
              count: desk.todayDeposit,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  const CustomerSupportCollectionScreen(initialFilter: 'due'),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '지난 입금',
              subtitle: '예정일 지난 수금',
              icon: Icons.money_off_rounded,
              count: desk.overdueDeposit,
              alert: desk.overdueDeposit > 0,
              onTap: () => openThenRefresh(
                () => _openStepFuture(
                  context,
                  const CustomerSupportCollectionScreen(
                    initialFilter: 'overdue',
                  ),
                ),
              ),
            ),
          ),
          SupportHubCountBar(
            title: '현장 · 미완료',
            icon: Icons.assignment_late_outlined,
            count: desk.incomplete,
            alert: desk.incomplete > 0,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const CustomerSupportReceptionListScreen(
                  title: '현장 · 미완료',
                  incompleteOnly: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportHubTile(
            title: '현장 검색',
            subtitle: '완료 포함 · 현장·전화·주소',
            icon: Icons.location_searching_rounded,
            count: desk.all,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const CustomerSupportSiteSearchScreen(title: '현장 검색'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '도구',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '새 접수',
            subtitle: 'A/S 접수 후 바로 1차 상담',
            icon: Icons.add_ic_call_rounded,
            onTap: () => openThenRefresh(() => _openIntake(context)),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '방문 달력',
            subtitle: '주간표에서 빈 시간에 방문 · 월간은 발송·입금',
            icon: Icons.calendar_month_rounded,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const CustomerSupportScheduleCalendarScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'A/S 방문 팀',
            subtitle: '본사·지사 팀 수 · 팀원 이름',
            icon: Icons.groups_rounded,
            onTap: () => openThenRefresh(
              () => openSupportVisitTeamsScreen(context),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '현장 지도',
            subtitle: '미처리·방문을 큰 지도에서 · 가까운 순',
            icon: Icons.map_rounded,
            onTap: () => openThenRefresh(
              () => _openStepFuture(
                context,
                const SupportSitesMapScreen(pendingOnly: true),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'A/S 단가표',
            subtitle: '접수·상담 중 검색 · 추가·수정',
            icon: Icons.grid_on_rounded,
            onTap: () => openThenRefresh(
              () => _openStepFuture(context, const SupportUnitPriceScreen()),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '견적서',
            subtitle: '작성 · 이미지/PDF · 이메일',
            icon: Icons.request_quote_outlined,
            onTap: () => openThenRefresh(
              () => _openStep(context, SupportFlowStep.quote),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '세금계산서',
            subtitle: '지사별 발행 요청',
            icon: Icons.receipt_long_outlined,
            onTap: () =>
                openThenRefresh(() => _openStep(context, SupportFlowStep.tax)),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '자동문의고수',
            subtitle: '고수 문의 접수 · 팔로업',
            icon: Icons.headset_mic_rounded,
            onTap: () => openThenRefresh(
              () => _openStepFuture(context, const GosuHubScreen()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '그 외',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '완료확인서',
            subtitle: '사인 · 금액 · 자재',
            icon: Icons.draw_outlined,
            onTap: () => openThenRefresh(
              () => _openStep(context, SupportFlowStep.completion),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '교육 FAQ',
            subtitle: '자료 검색',
            icon: Icons.menu_book_outlined,
            onTap: () =>
                openThenRefresh(() => _openStep(context, SupportFlowStep.faq)),
          ),
        ],
      ),
    );
  }

  Future<void> _openStepFuture(BuildContext context, Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openIntake(BuildContext context) async {
    await openReceptionCreateHost(
      context,
      initialKind: ReceptionKind.afterSales,
    );
  }

  Future<void> _openStep(BuildContext context, SupportFlowStep step) {
    if (step == SupportFlowStep.intake) {
      return openSupportIntakeThenDetail(context);
    }
    final screen = switch (step) {
      SupportFlowStep.siteSearch => const CustomerSupportSiteSearchScreen(),
      SupportFlowStep.intake => const CustomerSupportIntakeScreen(),
      SupportFlowStep.receptionList =>
        const CustomerSupportReceptionListScreen(),
      SupportFlowStep.scheduleCalendar =>
        const CustomerSupportScheduleCalendarScreen(),
      SupportFlowStep.quote => const SupportQuoteWriterScreen(),
      SupportFlowStep.completion => const CustomerSupportCompletionScreen(),
      SupportFlowStep.collection => const CustomerSupportCollectionScreen(),
      SupportFlowStep.tax => const SupportIssuancePage(),
      SupportFlowStep.faq => const CustomerSupportFaqScreen(),
    };
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _HubTileRow extends StatelessWidget {
  const _HubTileRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 10),
            Expanded(child: right),
          ],
        ),
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.accent, required this.scheme});

  final Color accent;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, Color.lerp(accent, scheme.surface, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현장 보드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '접수 → 전화 상담 → 구두·정식 견적 → 방문 → 수금. 오늘 할 일은 홈에서도 바로 조치합니다.',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onPrimary.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}
