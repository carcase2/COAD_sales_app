import 'dart:async';

import 'package:coad_customer_calls/features/issuance/issuance_completed_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_filtered_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
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
  bool _refreshing = false;

  Future<void> _reloadIssuanceData() async {
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.taxInvoice));
    ref.invalidate(issuanceAllRowsProvider(IssuanceDomain.performanceBond));
    ref.invalidate(issuanceCancelledRowsProvider(IssuanceDomain.taxInvoice));
    ref.invalidate(
      issuanceCancelledRowsProvider(IssuanceDomain.performanceBond),
    );
    ref.invalidate(issuanceRequestBadgeCountProvider);
    ref.invalidate(issuanceRequestTotalBadgeCountProvider);
    await Future.wait([
      ref.read(issuanceAllRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(issuanceAllRowsProvider(IssuanceDomain.performanceBond).future),
    ]);
  }

  Future<void> _refreshIssuanceData({bool showCompletionSnackBar = false}) {
    return runIssuanceRefresh(
      context: context,
      onLoadingChanged: (loading) => setState(() => _refreshing = loading),
      showCompletionSnackBar: showCompletionSnackBar,
      action: _reloadIssuanceData,
    );
  }

  Future<bool> _tryOpenDetailByIds({
    required IssuanceDomain domain,
    required String masterId,
    String? issueId,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        if (!mounted) return false;
      }
      ref.invalidate(issuanceAllRowsProvider(domain));
      try {
        final rows = await ref.read(issuanceAllRowsProvider(domain).future);
        final target = findIssuanceRowByIds(
          rows,
          masterId: masterId,
          issueId: issueId,
        );
        if (target == null || !mounted) continue;
        showIssuanceRequestDetail(context, target);
        return true;
      } catch (_) {
        // 다음 시도에서 재조회
      }
    }
    return false;
  }

  void _consumePendingLaunch() {
    final next = ref.read(pendingIssuanceLaunchProvider);
    if (next == null) return;
    setState(() => _domain = next.domain);
    ref.read(pendingIssuanceLaunchProvider.notifier).state = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final masterId = next.masterId?.trim() ?? '';
      if (masterId.isNotEmpty) {
        final opened = await _tryOpenDetailByIds(
          domain: next.domain,
          masterId: masterId,
          issueId: next.issueId,
        );
        if (opened) return;
      }
      if (next.showCompleted) {
        await _openCompletedListPage(
          openMasterId: next.masterId,
          openIssueId: next.issueId,
        );
      } else {
        await _openListPage(
          next.listKind ?? IssuanceListKind.request,
          domain: next.domain,
          openMasterId: next.masterId,
          openIssueId: next.issueId,
        );
      }
    });
  }

  Future<void> _openListPage(
    IssuanceListKind kind, {
    IssuanceDomain? domain,
    String? openMasterId,
    String? openIssueId,
  }) async {
    final d = domain ?? _domain;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IssuanceFilteredListPage(
          domain: d,
          kind: kind,
          openMasterId: openMasterId,
          openIssueId: openIssueId,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshIssuanceData();
  }

  Future<void> _openCompletedListPage({
    String? openMasterId,
    String? openIssueId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IssuanceCompletedListPage(
          domain: _domain,
          openMasterId: openMasterId,
          openIssueId: openIssueId,
        ),
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
    final myPendingAsync = ref.watch(issuanceMyRequestRowsProvider(_domain));
    final partialAsync = ref.watch(issuancePartialRowsProvider(_domain));
    final fullyCompletedAsync = ref.watch(
      issuanceFullyCompletedRowsProvider(_domain),
    );
    final allAsync = ref.watch(issuanceAllTabRowsProvider(_domain));
    final completedAsync = ref.watch(issuanceCompletedRowsProvider(_domain));
    final cancelledAsync = ref.watch(issuanceCancelledRowsProvider(_domain));
    final taxPendingAsync = ref.watch(
      issuanceMyRequestRowsProvider(IssuanceDomain.taxInvoice),
    );
    final bondPendingAsync = ref.watch(
      issuanceMyRequestRowsProvider(IssuanceDomain.performanceBond),
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
                        tooltip: _refreshing ? '새로고침 중…' : '새로고침',
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _refreshing
                            ? null
                            : () => unawaited(
                                  _refreshIssuanceData(
                                    showCompletionSnackBar: true,
                                  ),
                                ),
                        icon: issuanceRefreshButtonIcon(
                          loading: _refreshing,
                          size: 18,
                          color: Colors.white,
                        ),
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
                label: const Text('발급 요청하기'),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _HubMenuTile(
                    icon: IssuanceListKind.request.icon,
                    title: IssuanceListKind.request.title,
                    count: count(myPendingAsync),
                    subtitle: pendingAsync.valueOrNull == null
                        ? null
                        : '전체 ${pendingAsync.value!.length}',
                    accent: Colors.blue.shade700,
                    large: true,
                    onTap: () => _openListPage(IssuanceListKind.request),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.1,
                    children: [
                      if (isTax)
                        _HubMenuTile(
                          icon: IssuanceListKind.partial.icon,
                          title: IssuanceListKind.partial.title,
                          count: count(partialAsync),
                          accent: Colors.orange.shade800,
                          onTap: () => _openListPage(IssuanceListKind.partial),
                        ),
                      if (isTax)
                        _HubMenuTile(
                          icon: IssuanceListKind.fullyCompleted.icon,
                          title: IssuanceListKind.fullyCompleted.title,
                          count: count(fullyCompletedAsync),
                          accent: Colors.green.shade700,
                          onTap: () => _openListPage(
                            IssuanceListKind.fullyCompleted,
                          ),
                        ),
                      _HubMenuTile(
                        icon: Icons.check_circle_outline_rounded,
                        title: '발급완료',
                        count: count(completedAsync),
                        accent: Colors.teal.shade700,
                        onTap: _openCompletedListPage,
                      ),
                      _HubMenuTile(
                        icon: IssuanceListKind.cancelled.icon,
                        title: IssuanceListKind.cancelled.title,
                        count: count(cancelledAsync),
                        accent: Colors.grey.shade700,
                        onTap: () =>
                            _openListPage(IssuanceListKind.cancelled),
                      ),
                      _HubMenuTile(
                        icon: IssuanceListKind.all.icon,
                        title: IssuanceListKind.all.title,
                        count: count(allAsync),
                        accent: scheme.onSurface,
                        onTap: () => _openListPage(IssuanceListKind.all),
                      ),
                    ],
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
    required this.count,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color accent;
  final VoidCallback onTap;
  final String? subtitle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(large ? 14 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(large ? 14 : 12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 14 : 10,
            vertical: large ? 14 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(large ? 14 : 12),
            border: Border.all(
              color: accent.withValues(alpha: large ? 0.35 : 0.22),
              width: large ? 1.5 : 1,
            ),
            boxShadow: large
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: large
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle == null
                                ? '내 발급요청 확인'
                                : '내 $count건 · $subtitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                        fontSize: 30,
                        height: 1,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: accent, size: 18),
                        const Spacer(),
                        if (subtitle != null) ...[
                          Flexible(
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: accent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
