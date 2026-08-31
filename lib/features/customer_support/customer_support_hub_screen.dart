import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_completion_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_faq_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_quote_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_schedule_calendar_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_site_search_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/reception_create_host_screen.dart';
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_branch_picker.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_sites_map_screen.dart';
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

    Future<void> openWithBranch({
      required String pickerTitle,
      required String pickerSubtitle,
      required Future<Iterable<String>> Function() addresses,
      required Widget Function(String branch) screen,
    }) async {
      final branch = await pickSupportBranch(
        context: context,
        ref: ref,
        title: pickerTitle,
        subtitle: pickerSubtitle,
        loadAddresses: addresses,
      );
      if (branch == null || !context.mounted) return;
      await _openStepFuture(context, screen(branch));
    }

    Future<Iterable<String>> logAddresses(
      Future<List<SupportCallLog>> Function() load,
    ) async {
      return (await load()).map((e) => e.address ?? '');
    }

    final repo = ref.read(supportCallLogRepositoryProvider);
    final today = todayYmdSeoul();
    final month = seoulMonthRangeContaining(today);

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
          _FlowHeader(
            accent: accent,
            scheme: scheme,
            onStepTap: (step) {
              if (step == SupportFlowStep.intake) {
                unawaited(openThenRefresh(() => _openIntake(context)));
                return;
              }
              unawaited(openThenRefresh(() => _openStep(context, step)));
            },
          ),
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
                    if (desk.todayPending > 0) '금일 미처리 ${desk.todayPending}',
                    if (desk.pending > 0) '전체 미처리 ${desk.pending}',
                    if (desk.overdueVisit > 0) '지난 방문 ${desk.overdueVisit}',
                    if (desk.overdueDeposit > 0) '지난 입금 ${desk.overdueDeposit}',
                  ].join(' · '),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  '접수를 놓치지 말고 방문·수금을 먼저 챙기세요.',
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
            title: '전체 미처리',
            icon: Icons.phone_callback_rounded,
            count: desk.pending,
            alert: desk.pending > 0,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '미처리 지사 선택',
                pickerSubtitle: '날짜 상관없이 1차 상담 전',
                addresses: () => logAddresses(
                  () => repo.list(pendingOnly: true, limit: 200),
                ),
                screen: (branch) => CustomerSupportReceptionListScreen(
                  title: '전체 A/S 미처리',
                  pendingOnly: true,
                  initialBranch: branch,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportHubCountBar(
            title: '전체 미완료',
            icon: Icons.assignment_late_outlined,
            count: desk.incomplete,
            alert: desk.incomplete > 0,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '미완료 지사 선택',
                pickerSubtitle: '마무리·방문 완료가 아닌 모든 건',
                addresses: () => logAddresses(
                  () => repo.list(incompleteOnly: true, limit: 400),
                ),
                screen: (branch) => CustomerSupportReceptionListScreen(
                  title: '전체 A/S 미완료',
                  incompleteOnly: true,
                  initialBranch: branch,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HubTileRow(
            left: SupportHubTile(
              title: '금일 미처리',
              subtitle: '오늘 접수 · 1차 상담 전',
              icon: Icons.today_rounded,
              count: desk.todayPending,
              alert: desk.todayPending > 0,
              onTap: () => openThenRefresh(
                () => openWithBranch(
                  pickerTitle: '미처리 지사 선택',
                  pickerSubtitle: '오늘 접수 · 1차 상담 전',
                  addresses: () => logAddresses(
                    () => repo.list(
                      pendingOnly: true,
                      fromYmd: today,
                      toYmdInclusive: today,
                      limit: 200,
                    ),
                  ),
                  screen: (branch) => CustomerSupportReceptionListScreen(
                    title: '금일 A/S 미처리',
                    fromYmd: today,
                    toYmdInclusive: today,
                    pendingOnly: true,
                    initialBranch: branch,
                  ),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '답 대기·견적서',
              subtitle: '안내 후 피드백 · 구두 견적 · 정식 견적서',
              icon: Icons.timelapse_rounded,
              count: desk.inProgress,
              onTap: () => openThenRefresh(
                () => openWithBranch(
                  pickerTitle: '답 대기 지사 선택',
                  pickerSubtitle: '안내 후 피드백 · 구두 견적 · 정식 견적서',
                  addresses: () => logAddresses(
                    () => repo.list(
                      statusId: kSupportStatusInProgress,
                      limit: 200,
                    ),
                  ),
                  screen: (branch) => CustomerSupportReceptionListScreen(
                    title: '답 대기·견적서',
                    statusId: kSupportStatusInProgress,
                    initialStatusTab: '답 대기·견적서',
                    initialBranch: branch,
                  ),
                ),
              ),
            ),
          ),
          _HubTileRow(
            left: SupportHubTile(
              title: '금일 방문예정',
              subtitle: '오늘 방문하기로 한 건 · 방문 기록',
              icon: Icons.event_available_rounded,
              count: desk.todayVisit,
              alert: desk.todayVisit > 0,
              onTap: () => openThenRefresh(
                () => openWithBranch(
                  pickerTitle: '방문 지사 선택',
                  pickerSubtitle: '오늘 방문하기로 한 건',
                  addresses: () => logAddresses(
                    () => repo.list(
                      visitOnly: true,
                      fromYmd: today,
                      toYmdInclusive: today,
                      limit: 200,
                    ),
                  ),
                  screen: (branch) => CustomerSupportScheduleCalendarScreen(
                    initialKind: SupportScheduleKind.visit,
                    initialBranch: branch,
                    initialYmd: today,
                  ),
                ),
              ),
            ),
            right: SupportHubTile(
              title: '지난 방문예정',
              subtitle: '날짜가 지난 방문 · 재방문',
              icon: Icons.event_busy_rounded,
              count: desk.overdueVisit,
              alert: desk.overdueVisit > 0,
              onTap: () => openThenRefresh(
                () => openWithBranch(
                  pickerTitle: '방문 지사 선택',
                  pickerSubtitle: '날짜가 지난 방문',
                  addresses: () async {
                    final events = await repo.listDueScheduleEvents(
                      todayYmd: today,
                    );
                    return events
                        .where(
                          (e) =>
                              e.kind == SupportScheduleKind.visit &&
                              e.ymd.compareTo(today) < 0,
                        )
                        .map((e) => e.log.address ?? '');
                  },
                  screen: (branch) => CustomerSupportScheduleCalendarScreen(
                    initialKind: SupportScheduleKind.visit,
                    initialBranch: branch,
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
                () => openWithBranch(
                  pickerTitle: '입금 지사 선택',
                  pickerSubtitle: '오늘 입금 예정',
                  addresses: () async {
                    final events = await repo.listDueScheduleEvents(
                      todayYmd: today,
                    );
                    return events
                        .where(
                          (e) =>
                              e.kind == SupportScheduleKind.deposit &&
                              e.ymd == today &&
                              e.depositPaid != true,
                        )
                        .map((e) => e.log.address ?? '');
                  },
                  screen: (branch) => CustomerSupportCollectionScreen(
                    initialBranch: branch,
                    initialFilter: 'due',
                  ),
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
                () => openWithBranch(
                  pickerTitle: '입금 지사 선택',
                  pickerSubtitle: '예정일이 지난 수금',
                  addresses: () async {
                    final events = await repo.listDueScheduleEvents(
                      todayYmd: today,
                    );
                    return events
                        .where(
                          (e) =>
                              e.kind == SupportScheduleKind.deposit &&
                              e.ymd.compareTo(today) < 0 &&
                              e.depositPaid != true,
                        )
                        .map((e) => e.log.address ?? '');
                  },
                  screen: (branch) => CustomerSupportCollectionScreen(
                    initialBranch: branch,
                    initialFilter: 'overdue',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SupportSectionCard(
            title: '새 접수',
            subtitle: 'A/S 접수 후 바로 1차 상담',
            icon: Icons.add_ic_call_rounded,
            onTap: () => openThenRefresh(() => _openIntake(context)),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'A/S 접수내역',
            subtitle: '미처리 · 답 대기·견적서 · 방문예정 · 완료',
            icon: Icons.list_alt_rounded,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '접수 지사 선택',
                pickerSubtitle: 'A/S 접수내역',
                addresses: () => logAddresses(() => repo.list(limit: 150)),
                screen: (branch) =>
                    CustomerSupportReceptionListScreen(initialBranch: branch),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '현장 지도',
            subtitle: '미처리·방문을 큰 지도에서 · 가까운 순',
            icon: Icons.map_rounded,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '지도 지사 선택',
                pickerSubtitle: '미처리·방문을 큰 지도에서',
                addresses: () => logAddresses(() => repo.listForMap()),
                screen: (branch) => SupportSitesMapScreen(
                  pendingOnly: true,
                  initialBranch: branch,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '방문 · 발송 달력',
            subtitle: '방문 · 견적 발송 · 입금 일정',
            icon: Icons.calendar_month_rounded,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '일정 지사 선택',
                pickerSubtitle: '방문 · 견적 발송 · 입금',
                addresses: () async {
                  final events = await repo.listScheduleEvents(
                    fromYmd: month.$1,
                    toYmdInclusive: month.$2,
                  );
                  return events.map((e) => e.log.address ?? '');
                },
                screen: (branch) => CustomerSupportScheduleCalendarScreen(
                  initialBranch: branch,
                ),
              ),
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
            title: '수금관리',
            subtitle: '입금예정 · 지난 수금 · 입금완료',
            icon: Icons.payments_outlined,
            onTap: () => openThenRefresh(
              () => openWithBranch(
                pickerTitle: '수금 지사 선택',
                pickerSubtitle: '입금예정 · 지난 수금 · 입금완료',
                addresses: () async {
                  final events = await repo.listDueScheduleEvents(
                    todayYmd: today,
                  );
                  return events
                      .where((e) => e.kind == SupportScheduleKind.deposit)
                      .map((e) => e.log.address ?? '');
                },
                screen: (branch) =>
                    CustomerSupportCollectionScreen(initialBranch: branch),
              ),
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
            title: '현장검색',
            subtitle: '주소 · 담당자 · 전화',
            icon: Icons.location_searching_rounded,
            onTap: () => openThenRefresh(
              () => _openStep(context, SupportFlowStep.siteSearch),
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
      SupportFlowStep.quote => const CustomerSupportQuoteScreen(),
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

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
    required this.accent,
    required this.scheme,
    required this.onStepTap,
  });

  final Color accent;
  final ColorScheme scheme;
  final ValueChanged<SupportFlowStep> onStepTap;

  static const _steps = <(SupportFlowStep, String)>[
    (SupportFlowStep.intake, '접수'),
    (SupportFlowStep.siteSearch, '현장'),
    (SupportFlowStep.quote, '견적'),
    (SupportFlowStep.completion, '완료'),
    (SupportFlowStep.collection, '수금'),
    (SupportFlowStep.tax, '세금계산서'),
  ];

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
            'AS 업무 흐름',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: scheme.onPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '접수 → 1차 상담(마무리·피드백·견적·방문) → 방문 기록 → 수금. 놓친 건은 위에서 먼저 보입니다.',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onPrimary.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                _StepChip(
                  label: '${i + 1} ${_steps[i].$2}',
                  onTap: () => onStepTap(_steps[i].$1),
                ),
                if (i < _steps.length - 1)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: scheme.onPrimary.withValues(alpha: 0.7),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onPrimary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
