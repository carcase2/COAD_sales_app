import 'dart:async';

import 'package:coad_customer_calls/features/issuance/issuance_completed_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_filtered_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 발급요청 허브 — 메뉴에서 각 목록을 전용 화면으로 연다.
class IssuanceRequestScreen extends ConsumerStatefulWidget {
  const IssuanceRequestScreen({super.key});

  @override
  ConsumerState<IssuanceRequestScreen> createState() =>
      _IssuanceRequestScreenState();
}

class _IssuanceRequestScreenState extends ConsumerState<IssuanceRequestScreen> {
  IssuanceDomain _domain = IssuanceDomain.taxInvoice;
  bool _isListeningLaunch = false;

  Future<void> _refreshIssuanceData() async {
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
    ref.invalidate(issuanceRequestBadgeCountProvider);
    await Future.wait([
      ref.read(issuanceAllRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(issuanceAllRowsProvider(IssuanceDomain.performanceBond).future),
    ]);
  }

  void _consumePendingLaunch() {
    final next = ref.read(pendingIssuanceLaunchProvider);
    if (next == null) return;
    setState(() => _domain = next.domain);
    ref.read(pendingIssuanceLaunchProvider.notifier).state = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (next.showCompleted) {
        unawaited(_openCompletedListPage());
      } else {
        unawaited(_openListPage(IssuanceListKind.request, domain: next.domain));
      }
    });
  }

  Future<void> _openListPage(
    IssuanceListKind kind, {
    IssuanceDomain? domain,
  }) async {
    final d = domain ?? _domain;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IssuanceFilteredListPage(domain: d, kind: kind),
      ),
    );
    if (!mounted) return;
    await _refreshIssuanceData();
  }

  Future<void> _openCompletedListPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IssuanceCompletedListPage(domain: _domain),
      ),
    );
    if (!mounted) return;
    await _refreshIssuanceData();
  }

  Future<void> _openCreateForCurrentDomain() async {
    final selected = _domain;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IssuanceRequestCreateScreen(initialDomain: selected),
      ),
    );
    if (created == true && mounted) {
      setState(() => _domain = selected);
      await _refreshIssuanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isListeningLaunch) {
      _isListeningLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _consumePendingLaunch();
      });
      ref.listen<IssuanceLaunchTarget?>(pendingIssuanceLaunchProvider, (_, _) {
        if (!mounted) return;
        _consumePendingLaunch();
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final pendingAsync = ref.watch(issuanceRequestRowsProvider(_domain));
    final partialAsync = ref.watch(issuancePartialRowsProvider(_domain));
    final allAsync = ref.watch(issuanceAllTabRowsProvider(_domain));
    final completedAsync = ref.watch(issuanceCompletedRowsProvider(_domain));
    final taxPendingAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.taxInvoice),
    );
    final bondPendingAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.performanceBond),
    );
    final taxCount = taxPendingAsync.valueOrNull?.length;
    final bondCount = bondPendingAsync.valueOrNull?.length;
    final isTax = _domain == IssuanceDomain.taxInvoice;
    final accent = isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;

    int count(AsyncValue<List<IssuanceRequestRow>> async) =>
        async.valueOrNull?.length ?? 0;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.92),
                    accent.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '발급요청',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '새로고침',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => unawaited(_refreshIssuanceData()),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildDomainTabButton(
                          label: '세금계산서',
                          count: taxCount,
                          selected: _domain == IssuanceDomain.taxInvoice,
                          accent: accent,
                          onTap: () => setState(
                            () => _domain = IssuanceDomain.taxInvoice,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildDomainTabButton(
                          label: '이행증권',
                          count: bondCount,
                          selected: _domain == IssuanceDomain.performanceBond,
                          accent: accent,
                          onTap: () => setState(
                            () => _domain = IssuanceDomain.performanceBond,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openCreateForCurrentDomain,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('발급하기'),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshIssuanceData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text(
                    '목록 보기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HubMenuTile(
                    icon: IssuanceListKind.request.icon,
                    title: IssuanceListKind.request.title,
                    subtitle: '미발급 요청 · 처리 필요',
                    count: count(pendingAsync),
                    accent: Colors.blue.shade700,
                    onTap: () => _openListPage(IssuanceListKind.request),
                  ),
                  const SizedBox(height: 10),
                  _HubMenuTile(
                    icon: IssuanceListKind.partial.icon,
                    title: IssuanceListKind.partial.title,
                    subtitle: '일부 발급 후 남은 %',
                    count: count(partialAsync),
                    accent: Colors.orange.shade800,
                    onTap: () => _openListPage(IssuanceListKind.partial),
                  ),
                  const SizedBox(height: 10),
                  _HubMenuTile(
                    icon: IssuanceListKind.all.icon,
                    title: IssuanceListKind.all.title,
                    subtitle: '진행 중인 모든 건',
                    count: count(allAsync),
                    accent: scheme.onSurface,
                    onTap: () => _openListPage(IssuanceListKind.all),
                  ),
                  const SizedBox(height: 10),
                  _HubMenuTile(
                    icon: Icons.check_circle_outline_rounded,
                    title: '발급완료',
                    subtitle: '실제 발급된 이력',
                    count: count(completedAsync),
                    accent: Colors.teal.shade700,
                    onTap: _openCompletedListPage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainTabButton({
    required String label,
    required int? count,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final countText = count == null ? '…' : '$count';
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? accent
                      : Colors.white.withValues(alpha: 0.92),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? accent : Colors.white,
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

class _HubMenuTile extends StatelessWidget {
  const _HubMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count건',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: accent,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
