import 'package:coad_customer_calls/core/constants/app_meta.dart';
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
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('고객지원팀')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _FlowHeader(
            accent: accent,
            scheme: scheme,
            onStepTap: (step) {
              if (step == SupportFlowStep.intake) {
                _openIntake(context);
                return;
              }
              _openStep(context, step);
            },
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: [
              SupportHubTile(
                title: '현장검색',
                subtitle: '주소·담당자·전화·현장명',
                icon: Icons.location_searching_rounded,
                onTap: () => _openStep(context, SupportFlowStep.siteSearch),
              ),
              SupportHubTile(
                title: '접수',
                subtitle: 'A/S · 영업 선택 등록',
                icon: Icons.add_ic_call_rounded,
                onTap: () => _openIntake(context),
              ),
              SupportHubTile(
                title: '견적서',
                subtitle: '단가표 · PDF · 저장',
                icon: Icons.request_quote_outlined,
                onTap: () => _openStep(context, SupportFlowStep.quote),
              ),
              SupportHubTile(
                title: '수금관리',
                subtitle: '유무상 · 입금예정 · 통계',
                icon: Icons.payments_outlined,
                onTap: () => _openStep(context, SupportFlowStep.collection),
              ),
              SupportHubTile(
                title: '완료확인서',
                subtitle: '사인 · 금액 · 자재',
                icon: Icons.draw_outlined,
                onTap: () => _openStep(context, SupportFlowStep.completion),
              ),
              SupportHubTile(
                title: '교육 FAQ',
                subtitle: '자료 작성 · 검색 · 이미지',
                icon: Icons.menu_book_outlined,
                onTap: () => _openStep(context, SupportFlowStep.faq),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SupportSectionCard(
            title: 'A/S 접수내역',
            subtitle: '저장한 접수 확인 · 검색',
            icon: Icons.list_alt_rounded,
            onTap: () => _openStep(context, SupportFlowStep.receptionList),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '방문 · 발송 달력',
            subtitle: '방문예정일 · 견적서 발송예정일',
            icon: Icons.calendar_month_rounded,
            onTap: () => _openStep(context, SupportFlowStep.scheduleCalendar),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: '세금계산서',
            subtitle: '지사별 개별 발행 요청 · 완료 알림',
            icon: Icons.receipt_long_outlined,
            onTap: () => _openStep(context, SupportFlowStep.tax),
          ),
          const SizedBox(height: 20),
          Text(
            '오늘',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(
                child: _TodayStat(label: '방문 예정', value: '0'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TodayStat(label: '입금 예정', value: '0'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _TodayStat(label: '지난 수금', value: '0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openIntake(BuildContext context) async {
    final kind = await showReceptionKindSheet(context);
    if (kind == null || !context.mounted) return;
    switch (kind) {
      case ReceptionKind.afterSales:
        _openStep(context, SupportFlowStep.intake);
      case ReceptionKind.sales:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: kSalesCallCreateRouteName),
            builder: (_) => const SalesCallCreateScreen(),
          ),
        );
    }
  }

  void _openStep(BuildContext context, SupportFlowStep step) {
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
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
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
            '현장 한 건을 고르면 접수부터 세금계산서까지 이어집니다.',
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

class _TodayStat extends StatelessWidget {
  const _TodayStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
