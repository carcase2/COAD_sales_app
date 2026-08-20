import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/quoter/quoter_hub_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:flutter/material.dart';

class CustomerSupportQuoteScreen extends StatelessWidget {
  const CustomerSupportQuoteScreen({super.key, this.site});

  final SupportSiteSample? site;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(site == null ? '견적서' : '${site!.name} 견적')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                const SupportComingSoonBanner(
                  message: '기존 견적기·단가표로 연결합니다. 메일·이미지 저장은 다음 작업입니다.',
                ),
                if (site != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '현장: ${site!.name} · ${site!.address}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                SupportSectionCard(
                  title: 'A. 단가표',
                  subtitle: '기존 사용 단가표 적용 · 검색',
                  icon: Icons.grid_on_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StandardUnitPriceScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SupportSectionCard(
                  title: '셔터 견적기',
                  subtitle: '폭·높이 계산',
                  icon: Icons.calculate_outlined,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QuoterHubScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SupportSectionCard(
                  title: '견적서 작성',
                  subtitle: '기존 견적서 작성 화면',
                  icon: Icons.edit_document,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const QuoterHubScreen(initialTabIndex: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SupportSectionCard(
                  title: 'B. 이메일 발송',
                  subtitle: 'PDF 변환 후 메일',
                  icon: Icons.email_outlined,
                  onTap: () => showSupportSkeletonSnack(context, '이메일 PDF 발송'),
                ),
                const SizedBox(height: 8),
                SupportSectionCard(
                  title: 'C. 휴대폰 이미지 저장',
                  subtitle: '견적서 이미지로 보관',
                  icon: Icons.photo_outlined,
                  onTap: () => showSupportSkeletonSnack(context, '이미지 저장'),
                ),
                const SizedBox(height: 8),
                SupportSectionCard(
                  title: 'D. 검색 · 일정',
                  subtitle: '기존 보낸 견적·방문 일정',
                  icon: Icons.event_note_outlined,
                  onTap: () => showSupportSkeletonSnack(context, '견적 일정'),
                ),
              ],
            ),
          ),
          UxActionDock(
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerSupportCollectionScreen(),
                  ),
                ),
                child: const Text('다음 · 수금관리'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
