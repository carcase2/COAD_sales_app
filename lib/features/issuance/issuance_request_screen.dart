import 'dart:async';

import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/issuance/issuance_completed_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_filtered_list_page.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_card.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_tax_issue_sheet.dart';
import 'package:coad_customer_calls/features/issuance/issuance_theme.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
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
  bool _consumingLaunch = false;
  bool _refreshing = false;
  bool _hubDetailReady = false;

  /// 금일 발급완료 아래 부가 목록(부분발급·완료·취소 등) — 기본 접힘.
  bool _moreListsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hubDetailReady = true);
    });
  }

  Future<void> _reloadIssuanceData() async {
    invalidateIssuanceCore(ref);
    await refreshIssuanceHubSummary(ref);
    if (_hubDetailReady) {
      await Future.wait([
        ref.read(issuanceAllRowsProvider(_domain).future),
        ref.read(issuanceCancelledRowsProvider(_domain).future),
      ]);
    }
  }

  Future<void> _refreshIssuanceData({bool showCompletionSnackBar = false}) {
    return runIssuanceRefresh(
      context: context,
      onLoadingChanged: (loading) => setState(() => _refreshing = loading),
      showCompletionSnackBar: showCompletionSnackBar,
      action: _reloadIssuanceData,
    );
  }

  Future<void> _consumePendingLaunch() async {
    if (_consumingLaunch) return;
    final next = ref.read(pendingIssuanceLaunchProvider);
    if (next == null || !mounted) return;
    _consumingLaunch = true;
    try {
      setState(() => _domain = next.domain);

      final masterId = next.masterId?.trim() ?? '';
      if (masterId.isNotEmpty) {
        // 상세 열기는 NotificationService가 담당 — 탭·도메인만 맞춘다.
        if (mounted) {
          ref.read(pendingIssuanceLaunchProvider.notifier).state = null;
        }
        return;
      }

      if (!mounted) return;
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
      if (!mounted) return;
      ref.read(pendingIssuanceLaunchProvider.notifier).state = null;
      NotificationService.clearPendingIssuanceNavigation();
    } finally {
      _consumingLaunch = false;
    }
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

  Future<void> _openCombinedPendingPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const _CombinedIssuancePendingPage()),
    );
    if (!mounted) return;
    await _refreshIssuanceData();
  }

  Future<void> _openCombinedTodayIssuedPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const _CombinedTodayIssuedPage()),
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
        unawaited(_consumePendingLaunch());
      });
      ref.listen<IssuanceLaunchTarget?>(pendingIssuanceLaunchProvider, (
        _,
        next,
      ) {
        if (!mounted || next == null) return;
        unawaited(_consumePendingLaunch());
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final taxPendingCountAsync = ref.watch(
      issuancePendingCountProvider(IssuanceDomain.taxInvoice),
    );
    final bondPendingCountAsync = ref.watch(
      issuancePendingCountProvider(IssuanceDomain.performanceBond),
    );
    final taxPendingCount = taxPendingCountAsync.valueOrNull;
    final bondPendingCount = bondPendingCountAsync.valueOrNull;
    final pendingCountsLoading =
        taxPendingCountAsync.isLoading || bondPendingCountAsync.isLoading;
    final combinedPendingCount =
        (taxPendingCount ?? 0) + (bondPendingCount ?? 0);
    final combinedPendingDisplay =
        pendingCountsLoading &&
            taxPendingCount == null &&
            bondPendingCount == null
        ? null
        : combinedPendingCount;

    AsyncValue<List<IssuanceRequestRow>> partialAsync = const AsyncValue.data(
      [],
    );
    AsyncValue<List<IssuanceRequestRow>> fullyCompletedAsync =
        const AsyncValue.data([]);
    AsyncValue<List<IssuanceRequestRow>> allAsync = const AsyncValue.data([]);
    AsyncValue<List<IssuanceRequestRow>> completedAsync = const AsyncValue.data(
      [],
    );
    AsyncValue<List<IssuanceRequestRow>> cancelledAsync = const AsyncValue.data(
      [],
    );
    AsyncValue<List<IssuanceRequestRow>> taxCompletedAsync =
        const AsyncValue.data([]);
    AsyncValue<List<IssuanceRequestRow>> bondCompletedAsync =
        const AsyncValue.data([]);

    if (_hubDetailReady) {
      partialAsync = ref.watch(issuancePartialRowsProvider(_domain));
      fullyCompletedAsync = ref.watch(
        issuanceFullyCompletedRowsProvider(_domain),
      );
      allAsync = ref.watch(issuanceAllTabRowsProvider(_domain));
      completedAsync = ref.watch(issuanceCompletedRowsProvider(_domain));
      cancelledAsync = ref.watch(issuanceCancelledRowsProvider(_domain));
      taxCompletedAsync = ref.watch(
        issuanceCompletedRowsProvider(IssuanceDomain.taxInvoice),
      );
      bondCompletedAsync = ref.watch(
        issuanceCompletedRowsProvider(IssuanceDomain.performanceBond),
      );
    }

    bool isTodayIssued(IssuanceRequestRow row) => issuanceIsTodayIssuedRow(row);

    final todayTaxIssued = _hubDetailReady
        ? (taxCompletedAsync.valueOrNull ?? const <IssuanceRequestRow>[])
              .where(isTodayIssued)
              .length
        : null;
    final todayBondIssued = _hubDetailReady
        ? (bondCompletedAsync.valueOrNull ?? const <IssuanceRequestRow>[])
              .where(isTodayIssued)
              .length
        : null;
    final todayIssuedCount = todayTaxIssued == null || todayBondIssued == null
        ? null
        : todayTaxIssued + todayBondIssued;
    final isTax = _domain == IssuanceDomain.taxInvoice;
    final accent = IssuanceVisual.domainAccent(_domain, scheme);

    int? countRows(AsyncValue<List<IssuanceRequestRow>> async) {
      if (!_hubDetailReady) return null;
      if (async.isLoading && async.valueOrNull == null) return null;
      return async.valueOrNull?.length ?? 0;
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: IssuanceVisual.hubHeader(_domain, scheme),
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
                          label: IssuanceVisual.domainLabel(
                            IssuanceDomain.taxInvoice,
                          ),
                          count: taxPendingCount,
                          selected: _domain == IssuanceDomain.taxInvoice,
                          accent: accent,
                          onTap: () => setState(
                            () => _domain = IssuanceDomain.taxInvoice,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildDomainTabButton(
                          label: IssuanceVisual.domainLabel(
                            IssuanceDomain.performanceBond,
                          ),
                          count: bondPendingCount,
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
                    title: '발급대기',
                    count: combinedPendingDisplay,
                    subtitle:
                        '전체 ${issuanceCountLabel(combinedPendingDisplay)}건 · '
                        '세금 ${issuanceCountLabel(taxPendingCount)} · '
                        '이행 ${issuanceCountLabel(bondPendingCount)}',
                    accent: IssuanceVisual.pendingTileAccent(scheme),
                    large: true,
                    onTap: _openCombinedPendingPage,
                  ),
                  const SizedBox(height: 8),
                  _HubMenuTile(
                    icon: Icons.task_alt_rounded,
                    title: '금일 발급완료',
                    count: todayIssuedCount,
                    subtitle:
                        '발급일 기준 · 세금 ${issuanceCountLabel(todayTaxIssued)} · '
                        '이행 ${issuanceCountLabel(todayBondIssued)}',
                    accent: IssuanceVisual.todayTileAccent(scheme),
                    large: true,
                    onTap: _openCombinedTodayIssuedPage,
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(
                        () => _moreListsExpanded = !_moreListsExpanded,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _moreListsExpanded ? '다른 목록 접기' : '다른 목록 펼치기',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '부분·완료·취소·전체',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _moreListsExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 22,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Builder(
                        builder: (context) {
                          final textScale = MediaQuery.textScalerOf(context)
                              .clamp(minScaleFactor: 1.0, maxScaleFactor: 1.4)
                              .scale(1.0);
                          final tileExtent = (88.0 * textScale).clamp(
                            88.0,
                            122.0,
                          );
                          return GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  mainAxisExtent: tileExtent,
                                ),
                            children: [
                              if (isTax)
                                _HubMenuTile(
                                  icon: IssuanceListKind.partial.icon,
                                  title: IssuanceListKind.partial.title,
                                  count: countRows(partialAsync),
                                  accent: IssuanceVisual.partialTileAccent(
                                    scheme,
                                  ),
                                  onTap: () =>
                                      _openListPage(IssuanceListKind.partial),
                                ),
                              if (isTax)
                                _HubMenuTile(
                                  icon: IssuanceListKind.fullyCompleted.icon,
                                  title: IssuanceListKind.fullyCompleted.title,
                                  count: countRows(fullyCompletedAsync),
                                  accent: IssuanceVisual.completedTileAccent(
                                    scheme,
                                  ),
                                  onTap: () => _openListPage(
                                    IssuanceListKind.fullyCompleted,
                                  ),
                                ),
                              _HubMenuTile(
                                icon: Icons.check_circle_outline_rounded,
                                title: '발급완료',
                                count: countRows(completedAsync),
                                accent: IssuanceVisual.completedTileAccent(
                                  scheme,
                                ),
                                onTap: _openCompletedListPage,
                              ),
                              _HubMenuTile(
                                icon: IssuanceListKind.cancelled.icon,
                                title: IssuanceListKind.cancelled.title,
                                count: countRows(cancelledAsync),
                                accent: IssuanceVisual.cancelledTileAccent(
                                  scheme,
                                ),
                                onTap: () =>
                                    _openListPage(IssuanceListKind.cancelled),
                              ),
                              _HubMenuTile(
                                icon: IssuanceListKind.all.icon,
                                title: IssuanceListKind.all.title,
                                count: countRows(allAsync),
                                accent: scheme.onSurfaceVariant,
                                onTap: () =>
                                    _openListPage(IssuanceListKind.all),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    crossFadeState: _moreListsExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeOutCubic,
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
  final int? count;
  final Color accent;
  final VoidCallback onTap;
  final String? subtitle;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countLabel = issuanceCountLabel(count);
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(large ? 14 : 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(large ? 14 : 12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: large ? 14 : 10,
            vertical: large ? 12 : 8,
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
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle == null ? '발급대기 목록' : subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      countLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        fontSize: 28,
                        height: 1,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: accent, size: 17),
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
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            countLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                              fontSize: 12,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          letterSpacing: -0.2,
                          height: 1.15,
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

class _CombinedIssuancePendingPage extends ConsumerStatefulWidget {
  const _CombinedIssuancePendingPage();

  @override
  ConsumerState<_CombinedIssuancePendingPage> createState() =>
      _CombinedIssuancePendingPageState();
}

class _CombinedIssuancePendingPageState
    extends ConsumerState<_CombinedIssuancePendingPage> {
  Future<void> _openTaxIssueSheet(IssuanceRequestRow row) async {
    final ok = await showTaxInvoiceIssueSheet(context: context, row: row);
    if (ok == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발급요청이 등록되었습니다.')));
    }
  }

  Future<void> _cancelRow(IssuanceRequestRow row) async {
    final masterId = row.master['id']?.toString();
    if (masterId == null || masterId.isEmpty) return;
    final user = ref.read(authControllerProvider);
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }
    final name = row.domain == IssuanceDomain.taxInvoice
        ? (row.master['customer_name'] ?? row.title).toString()
        : (row.master['company_name'] ?? row.title).toString();
    final reason = await showIssuanceCancelDialog(context, targetName: name);
    if (!mounted) return;
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(issuanceRequestServiceProvider)
          .cancelMaster(
            domain: row.domain,
            masterId: masterId,
            cancelledBy: user.name,
            cancelReason: reason,
          );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('발급요청이 취소되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(issuanceUserErrorMessage(e))));
    }
  }

  Future<void> _refresh() async {
    invalidateIssuanceCore(ref);
    await Future.wait([
      ref.read(issuanceRequestRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(
        issuanceRequestRowsProvider(IssuanceDomain.performanceBond).future,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(
      authControllerProvider.select(
        (u) => u == null ? null : (name: u.name, id: u.id),
      ),
    );
    final taxAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.taxInvoice),
    );
    final bondAsync = ref.watch(
      issuanceRequestRowsProvider(IssuanceDomain.performanceBond),
    );

    final taxRows = taxAsync.valueOrNull ?? const <IssuanceRequestRow>[];
    final bondRows = bondAsync.valueOrNull ?? const <IssuanceRequestRow>[];
    final taxMine = taxRows
        .where((r) => issuanceIsOwnRequest(r, user?.name, userId: user?.id))
        .toList();
    final bondMine = bondRows
        .where((r) => issuanceIsOwnRequest(r, user?.name, userId: user?.id))
        .toList();

    final loading = taxAsync.isLoading || bondAsync.isLoading;
    final hasError = taxAsync.hasError || bondAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('발급대기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '전체 대기',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : hasError
            ? issuanceListErrorScrollable(
                message: '발급대기 목록을 불러오지 못했습니다.',
                onRetry: _refresh,
              )
            : _buildPendingQueueList(
                context,
                scheme: scheme,
                user: user,
                taxRows: taxRows,
                bondRows: bondRows,
                taxMineCount: taxMine.length,
                bondMineCount: bondMine.length,
              ),
      ),
    );
  }

  Widget _buildPendingQueueList(
    BuildContext context, {
    required ColorScheme scheme,
    required ({String name, String id})? user,
    required List<IssuanceRequestRow> taxRows,
    required List<IssuanceRequestRow> bondRows,
    required int taxMineCount,
    required int bondMineCount,
  }) {
    if (taxRows.isEmpty && bondRows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: Text('발급대기 건이 없습니다.')),
          ),
        ],
      );
    }

    final itemCount = 1 + taxRows.length + 1 + 1 + bondRows.length;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader(
            context,
            title: IssuanceVisual.domainLabel(IssuanceDomain.taxInvoice),
            mineCount: taxMineCount,
            totalCount: taxRows.length,
            color: IssuanceVisual.domainAccent(
              IssuanceDomain.taxInvoice,
              scheme,
            ),
          );
        }
        if (index <= taxRows.length) {
          final row = taxRows[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IssuanceRequestCard(
                  row: row,
                  isOwn: issuanceIsOwnRequest(
                    row,
                    user?.name,
                    userId: user?.id,
                  ),
                  large: true,
                  onTap: () => showIssuanceRequestDetail(context, row),
                ),
                IssuanceRowActions(
                  row: row,
                  onIssue: _openTaxIssueSheet,
                  onCancel: (r) => _cancelRow(r),
                  onOpenDetail: null,
                ),
              ],
            ),
          );
        }
        if (index == taxRows.length + 1) {
          return const SizedBox(height: 8);
        }
        if (index == taxRows.length + 2) {
          return _buildSectionHeader(
            context,
            title: IssuanceVisual.domainLabel(IssuanceDomain.performanceBond),
            mineCount: bondMineCount,
            totalCount: bondRows.length,
            color: IssuanceVisual.domainAccent(
              IssuanceDomain.performanceBond,
              scheme,
            ),
          );
        }
        final row = bondRows[index - taxRows.length - 3];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IssuanceRequestCard(
                row: row,
                isOwn: issuanceIsOwnRequest(row, user?.name, userId: user?.id),
                large: true,
                onTap: () => showIssuanceRequestDetail(context, row),
              ),
              IssuanceRowActions(
                row: row,
                onIssue: _openTaxIssueSheet,
                onCancel: (r) => _cancelRow(r),
                onOpenDetail: null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int mineCount,
    required int totalCount,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
          Text(
            '내 $mineCount건 · 전체 $totalCount건',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinedTodayIssuedPage extends ConsumerWidget {
  const _CombinedTodayIssuedPage();

  Future<void> _refresh(WidgetRef ref) async {
    invalidateIssuanceCore(ref);
    await Future.wait([
      ref.read(issuanceCompletedRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(
        issuanceCompletedRowsProvider(IssuanceDomain.performanceBond).future,
      ),
    ]);
  }

  bool _isTodayIssued(IssuanceRequestRow row) => issuanceIsTodayIssuedRow(row);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(
      authControllerProvider.select(
        (u) => u == null ? null : (name: u.name, id: u.id),
      ),
    );
    final taxAsync = ref.watch(
      issuanceCompletedRowsProvider(IssuanceDomain.taxInvoice),
    );
    final bondAsync = ref.watch(
      issuanceCompletedRowsProvider(IssuanceDomain.performanceBond),
    );

    final taxRows = (taxAsync.valueOrNull ?? const <IssuanceRequestRow>[])
        .where(_isTodayIssued)
        .toList();
    final bondRows = (bondAsync.valueOrNull ?? const <IssuanceRequestRow>[])
        .where(_isTodayIssued)
        .toList();
    final loading = taxAsync.isLoading || bondAsync.isLoading;
    final hasError = taxAsync.hasError || bondAsync.hasError;

    final taxMineCount = taxRows
        .where((r) => issuanceIsOwnRequest(r, user?.name, userId: user?.id))
        .length;
    final bondMineCount = bondRows
        .where((r) => issuanceIsOwnRequest(r, user?.name, userId: user?.id))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('금일 발급완료')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : hasError
            ? issuanceListErrorScrollable(
                message: '금일 발급완료 목록을 불러오지 못했습니다.',
                onRetry: () => _refresh(ref),
              )
            : _buildIssuedQueueList(
                context,
                scheme: scheme,
                user: user,
                taxRows: taxRows,
                bondRows: bondRows,
                taxMineCount: taxMineCount,
                bondMineCount: bondMineCount,
              ),
      ),
    );
  }

  Widget _buildIssuedQueueList(
    BuildContext context, {
    required ColorScheme scheme,
    required ({String name, String id})? user,
    required List<IssuanceRequestRow> taxRows,
    required List<IssuanceRequestRow> bondRows,
    required int taxMineCount,
    required int bondMineCount,
  }) {
    if (taxRows.isEmpty && bondRows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: Center(child: Text('오늘 발급완료 건이 없습니다.')),
          ),
        ],
      );
    }

    final itemCount = 1 + taxRows.length + 1 + 1 + bondRows.length;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSectionHeader(
            context,
            title: IssuanceVisual.domainLabel(IssuanceDomain.taxInvoice),
            mineCount: taxMineCount,
            totalCount: taxRows.length,
            color: IssuanceVisual.domainAccent(
              IssuanceDomain.taxInvoice,
              scheme,
            ),
          );
        }
        if (index <= taxRows.length) {
          final row = taxRows[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IssuanceRequestCard(
              row: row,
              isOwn: issuanceIsOwnRequest(row, user?.name, userId: user?.id),
              large: true,
              onTap: () => showIssuanceRequestDetail(context, row),
            ),
          );
        }
        if (index == taxRows.length + 1) {
          return const SizedBox(height: 8);
        }
        if (index == taxRows.length + 2) {
          return _buildSectionHeader(
            context,
            title: IssuanceVisual.domainLabel(IssuanceDomain.performanceBond),
            mineCount: bondMineCount,
            totalCount: bondRows.length,
            color: IssuanceVisual.domainAccent(
              IssuanceDomain.performanceBond,
              scheme,
            ),
          );
        }
        final row = bondRows[index - taxRows.length - 3];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IssuanceRequestCard(
            row: row,
            isOwn: issuanceIsOwnRequest(row, user?.name, userId: user?.id),
            large: true,
            onTap: () => showIssuanceRequestDetail(context, row),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int mineCount,
    required int totalCount,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
          Text(
            '내 $mineCount건 · 전체 $totalCount건',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
