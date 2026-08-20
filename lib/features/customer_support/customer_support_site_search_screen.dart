import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_search_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_completion_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_quote_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/quoter/quoter_hub_screen.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerSupportSiteSearchScreen extends StatefulWidget {
  const CustomerSupportSiteSearchScreen({super.key});

  @override
  State<CustomerSupportSiteSearchScreen> createState() =>
      _CustomerSupportSiteSearchScreenState();
}

class _CustomerSupportSiteSearchScreenState
    extends State<CustomerSupportSiteSearchScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportSiteSample> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kSupportSampleSites;
    return kSupportSampleSites
        .where((s) {
          final blob = [
            s.name,
            s.address,
            s.phone,
            s.assignee,
            ...s.addresses,
            ...s.quotes,
          ].join(' ').toLowerCase();
          return blob.contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('현장검색'),
        actions: const [SupportExcelButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '주소 · 담당자 · 전화 · 현장명 · 견적',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ],
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SupportComingSoonBanner(
              message: '샘플 현장입니다. 체크시트·견적서는 기존 화면으로 연결됩니다.',
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const AppEmpty(
                    icon: Icons.location_off_outlined,
                    message: '검색 결과가 없습니다.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final site = items[i];
                      return _SiteResultTile(
                        site: site,
                        query: _query,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CustomerSupportSiteDetailScreen(site: site),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SiteResultTile extends StatelessWidget {
  const _SiteResultTile({
    required this.site,
    required this.query,
    required this.onTap,
  });

  final SupportSiteSample site;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchHighlightText(
                      text: site.name,
                      query: query,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '재방문 ${site.revisitCount}회',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                site.address,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                '${site.assignee} · ${site.phone}'
                '${site.installCompletedYmd == null ? ' · 설치미완료' : ' · 설치 ${site.installCompletedYmd}'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerSupportSiteDetailScreen extends StatelessWidget {
  const CustomerSupportSiteDetailScreen({super.key, required this.site});

  final SupportSiteSample site;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SiteHeader(site: site),
          const SizedBox(height: 12),
          SupportSectionCard(
            title: 'A. 재방문율',
            subtitle: '동일 현장 A/S ${site.revisitCount}회',
            icon: Icons.replay_circle_filled_outlined,
            badge: '${site.revisitCount}회',
            onTap: () => showSupportSkeletonSnack(context, '재방문 통계'),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'B. 히스토리',
            subtitle: site.history.isEmpty ? '이력 없음' : site.history.first,
            icon: Icons.history_rounded,
            badge: '${site.history.length}',
            onTap: () => _showLines(context, 'A/S 히스토리', site.history),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'C. 체크시트',
            subtitle: site.hasChecksheet
                ? '기존 체크시트 검색으로 이동'
                : '연결된 체크시트 없음 (검색은 가능)',
            icon: Icons.fact_check_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChecksheetSearchScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'D. 사업자등록증',
            subtitle: site.hasBusinessLicense ? '등록됨 · 미리보기 준비중' : '미등록',
            icon: Icons.badge_outlined,
            onTap: () => showSupportSkeletonSnack(context, '사업자등록증'),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'E. 주소',
            subtitle: site.addresses.join(' · '),
            icon: Icons.place_outlined,
            badge: '${site.addresses.length}곳',
            onTap: () => _showLines(context, '주소', site.addresses),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'F. 기존 견적서',
            subtitle: site.quotes.isEmpty
                ? '보낸 견적 없음 · 견적 화면으로 이동'
                : site.quotes.first,
            icon: Icons.request_quote_outlined,
            badge: site.quotes.isEmpty ? null : '${site.quotes.length}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const QuoterHubScreen(initialTabIndex: 1),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'G. 설치완료일',
            subtitle: site.installCompletedYmd ?? '아직 설치 완료 기록이 없습니다',
            icon: Icons.event_available_outlined,
            onTap: () => showSupportSkeletonSnack(context, '설치완료일'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerSupportIntakeScreen(site: site),
              ),
            ),
            icon: const Icon(Icons.add_ic_call_rounded),
            label: const Text('이 현장 AS 접수'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerSupportQuoteScreen(site: site),
              ),
            ),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('견적서'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerSupportCompletionScreen(site: site),
              ),
            ),
            child: Text('완료확인서로', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showLines(BuildContext context, String title, List<String> lines) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in lines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(line),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.site});

  final SupportSiteSample site;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            site.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${site.address}\n${site.assignee} · ${site.phone}',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
