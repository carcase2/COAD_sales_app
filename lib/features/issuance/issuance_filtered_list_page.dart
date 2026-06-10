import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_card.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_tax_issue_sheet.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 발급대기 / 부분발급 / 전체 전용 전체 화면 목록.
class IssuanceFilteredListPage extends ConsumerStatefulWidget {
  const IssuanceFilteredListPage({
    required this.domain,
    required this.kind,
    this.openMasterId,
    this.openIssueId,
    super.key,
  });

  final IssuanceDomain domain;
  final IssuanceListKind kind;
  final String? openMasterId;
  final String? openIssueId;

  @override
  ConsumerState<IssuanceFilteredListPage> createState() =>
      _IssuanceFilteredListPageState();
}

class _IssuanceFilteredListPageState
    extends ConsumerState<IssuanceFilteredListPage> {
  late IssuanceDomain _domain;

  bool _openedPendingDetail = false;
  bool _refreshing = false;

  /// 부분발급 담당자 필터 — null이면 전체.
  String? _assigneeFilter;
  bool _assigneeFilterInitialized = false;

  @override
  void initState() {
    super.initState();
    _domain = widget.domain;
  }

  void _maybeOpenPendingDetail(List<IssuanceRequestRow> rows) {
    if (_openedPendingDetail || !mounted) return;
    final masterId = widget.openMasterId;
    if (masterId == null || masterId.isEmpty) return;
    final issueId = widget.openIssueId;
    IssuanceRequestRow? target;
    for (final row in rows) {
      if (row.master['id']?.toString() != masterId) continue;
      if (issueId != null &&
          issueId.isNotEmpty &&
          row.issue?['id']?.toString() != issueId) {
        continue;
      }
      target = row;
      break;
    }
    if (target == null) {
      for (final row in rows) {
        if (row.master['id']?.toString() == masterId) {
          target = row;
          break;
        }
      }
    }
    if (target == null) return;
    _openedPendingDetail = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showIssuanceRequestDetail(context, target!);
    });
  }

  bool get _isTax => _domain == IssuanceDomain.taxInvoice;

  Future<void> _reloadRows() async {
    ref.invalidate(issuanceAllRowsProvider(_domain));
    ref.invalidate(issuanceCancelledRowsProvider(_domain));
    ref.invalidate(issuanceRequestBadgeCountProvider);
    ref.invalidate(issuanceRequestTotalBadgeCountProvider);
    await ref.read(issuanceAllRowsProvider(_domain).future);
  }

  Future<void> _refresh({bool showCompletionSnackBar = false}) {
    return runIssuanceRefresh(
      context: context,
      onLoadingChanged: (loading) => setState(() => _refreshing = loading),
      showCompletionSnackBar: showCompletionSnackBar,
      action: _reloadRows,
    );
  }

  AsyncValue<List<IssuanceRequestRow>> _rowsAsync() {
    switch (widget.kind) {
      case IssuanceListKind.request:
        return ref.watch(issuanceRequestRowsProvider(_domain));
      case IssuanceListKind.partial:
        return ref.watch(issuancePartialRowsProvider(_domain));
      case IssuanceListKind.fullyCompleted:
        return ref.watch(issuanceFullyCompletedRowsProvider(_domain));
      case IssuanceListKind.all:
        return ref.watch(issuanceAllTabRowsProvider(_domain));
      case IssuanceListKind.cancelled:
        return ref.watch(issuanceCancelledRowsProvider(_domain));
    }
  }

  Future<void> _openTaxIssueSheet(IssuanceRequestRow row) async {
    final ok = await showTaxInvoiceIssueSheet(context: context, row: row);
    if (ok == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발급요청이 등록되었습니다.')),
      );
    }
  }

  Future<void> _cancelRow(IssuanceRequestRow row) async {
    final masterId = row.master['id']?.toString();
    if (masterId == null || masterId.isEmpty) return;
    final user = ref.read(authControllerProvider);
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 필요합니다.')),
      );
      return;
    }
    final name = row.domain == IssuanceDomain.taxInvoice
        ? (row.master['customer_name'] ?? row.title).toString()
        : (row.master['company_name'] ?? row.title).toString();
    final reason = await showIssuanceCancelDialog(context, targetName: name);
    if (reason == null || !mounted) return;
    try {
      await ref.read(issuanceRequestServiceProvider).cancelMaster(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(issuanceUserErrorMessage(e))),
      );
    }
  }

  void _switchDomain(IssuanceDomain domain) {
    if (_domain == domain) return;
    setState(() {
      _domain = domain;
      _assigneeFilterInitialized = false;
      _assigneeFilter = null;
    });
  }

  /// 기본값: 로그인 사용자에게 부분발급 건이 있으면 본인, 없으면 전체.
  void _initAssigneeFilterIfNeeded(List<IssuanceRequestRow> rows) {
    if (widget.kind != IssuanceListKind.partial) return;
    if (_assigneeFilterInitialized) return;
    _assigneeFilterInitialized = true;
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final hasMine = rows.any((r) => issuanceIsOwnRequest(r, user.name));
    _assigneeFilter = hasMine ? user.name.trim() : null;
  }

  List<IssuanceRequestRow> _applyAssigneeFilter(
    List<IssuanceRequestRow> rows,
  ) {
    if (widget.kind != IssuanceListKind.partial) return rows;
    final filter = _assigneeFilter?.trim();
    if (filter == null || filter.isEmpty) return rows;
    return rows
        .where((r) => issuanceRequestOwnerName(r).trim() == filter)
        .toList();
  }

  Widget _buildAssigneeFilterBar(
    List<IssuanceRequestRow> rows,
    ColorScheme scheme,
  ) {
    final user = ref.watch(authControllerProvider);
    final myName = user?.name.trim() ?? '';
    final accent = _isTax
        ? Colors.indigo.shade600
        : Colors.deepOrange.shade700;

    final owners = <String>{
      for (final r in rows)
        if (issuanceRequestOwnerName(r).trim().isNotEmpty)
          issuanceRequestOwnerName(r).trim(),
    }.toList()..sort();
    // 본인을 맨 앞으로.
    if (owners.remove(myName)) owners.insert(0, myName);

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: accent.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? accent : scheme.onSurfaceVariant,
          fontSize: 12,
        ),
        visualDensity: VisualDensity.compact,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: Row(
        children: [
          Text(
            '담당자',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  chip(
                    label: '전체',
                    selected: _assigneeFilter == null,
                    onTap: () => setState(() => _assigneeFilter = null),
                  ),
                  for (final owner in owners) ...[
                    const SizedBox(width: 6),
                    chip(
                      label: owner == myName ? '$owner (나)' : owner,
                      selected: _assigneeFilter == owner,
                      onTap: () => setState(() => _assigneeFilter = owner),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainSwitcher(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _DomainTab(
                label: '세금계산서',
                selected: _isTax,
                accent: Colors.indigo.shade600,
                onTap: () => _switchDomain(IssuanceDomain.taxInvoice),
              ),
            ),
            Expanded(
              child: _DomainTab(
                label: '이행증권',
                selected: !_isTax,
                accent: Colors.deepOrange.shade700,
                onTap: () => _switchDomain(IssuanceDomain.performanceBond),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRequestsBanner({
    required int myCount,
    required int totalCount,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 발급요청',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '확인할 건 $myCount건 · 전체 $totalCount건',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$myCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    int count,
    Color color, {
    bool highlight = false,
  }) {
    if (highlight) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.35),
              endIndent: 8,
            ),
          ),
          Text(
            '$title $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Expanded(
            child: Divider(
              color: color.withValues(alpha: 0.35),
              indent: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowTile(IssuanceRequestRow row, {required bool isOwn}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IssuanceRequestCard(
          row: row,
          isOwn: isOwn,
          large: widget.kind == IssuanceListKind.request,
          onTap: () => showIssuanceRequestDetail(context, row),
        ),
        if (widget.kind == IssuanceListKind.request ||
            widget.kind == IssuanceListKind.partial)
          IssuanceRowActions(
            row: row,
            onIssue: _openTaxIssueSheet,
            onCancel: _cancelRow,
            onOpenDetail: () => showIssuanceRequestDetail(context, row),
          ),
      ],
    );
  }

  Widget _buildListBody(List<IssuanceRequestRow> rows, ColorScheme scheme) {
    final user = ref.watch(authControllerProvider);
    final displayRows = widget.kind == IssuanceListKind.request ||
            widget.kind == IssuanceListKind.partial
        ? sortIssuanceRowsOwnFirst(rows, user?.name)
        : rows;

    if (widget.kind != IssuanceListKind.request) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: displayRows.length,
        separatorBuilder: (_, index) => SizedBox(
          height: widget.kind == IssuanceListKind.request ? 12 : 10,
        ),
        itemBuilder: (context, index) {
          final row = displayRows[index];
          return _buildRowTile(
            row,
            isOwn: issuanceIsOwnRequest(row, user?.name),
          );
        },
      );
    }

    final split = splitIssuanceRowsByOwner(rows, user?.name);
    final ownAccent = _isTax
        ? Colors.indigo.shade600
        : Colors.deepOrange.shade700;
    final children = <Widget>[];
    if (split.mine.isNotEmpty) {
      children.add(
        _buildMyRequestsBanner(
          myCount: split.mine.length,
          totalCount: rows.length,
          accent: ownAccent,
        ),
      );
      children.add(
        _sectionHeader(
          '내 요청 목록',
          split.mine.length,
          ownAccent,
          highlight: true,
        ),
      );
      for (final row in split.mine) {
        children.add(_buildRowTile(row, isOwn: true));
        children.add(const SizedBox(height: 12));
      }
    }
    if (split.others.isNotEmpty) {
      children.add(
        _sectionHeader(
          '다른 요청',
          split.others.length,
          scheme.onSurfaceVariant,
        ),
      );
      for (var i = 0; i < split.others.length; i++) {
        children.add(
          Opacity(
            opacity: 0.88,
            child: _buildRowTile(split.others[i], isOwn: false),
          ),
        );
        if (i < split.others.length - 1) {
          children.add(const SizedBox(height: 10));
        }
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: children,
    );
  }

  String _listSubtitle(List<IssuanceRequestRow> rows) {
    if (widget.kind == IssuanceListKind.request) {
      final user = ref.watch(authControllerProvider);
      final split = splitIssuanceRowsByOwner(rows, user?.name);
      return '내 ${split.mine.length}건 · 전체 ${rows.length}건 · 미발급 발급요청';
    }
    return widget.kind.subtitle;
  }

  String _emptyMessage() {
    final domain = _isTax ? '세금계산서' : '이행증권';
    return switch (widget.kind) {
      IssuanceListKind.request => '$domain 발급대기 건이 없습니다.',
      IssuanceListKind.partial =>
        _isTax ? '부분발급 대상이 없습니다.' : '이행증권은 부분발급 목록을 사용하지 않습니다.',
      IssuanceListKind.fullyCompleted =>
        _isTax ? '100% 완료된 세금계산서가 없습니다.' : '완료 목록은 세금계산서만 제공합니다.',
      IssuanceListKind.all => '$domain 발급 건이 없습니다.',
      IssuanceListKind.cancelled => '$domain 취소 건이 없습니다.',
    };
  }

  Widget _emptyScrollable(String message, ColorScheme scheme) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowsAsync = _rowsAsync();
    final meta = widget.kind;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(meta.title),
        actions: [
          IconButton(
            tooltip: _refreshing ? '새로고침 중…' : '새로고침',
            onPressed: _refreshing
                ? null
                : () => _refresh(showCompletionSnackBar: true),
            icon: issuanceRefreshButtonIcon(loading: _refreshing),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDomainSwitcher(scheme),
          if (widget.kind != IssuanceListKind.request)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: rowsAsync.maybeWhen(
                data: (rows) => Text(
                  _listSubtitle(rows),
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                orElse: () => Text(
                  meta.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: rowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '목록을 불러오지 못했습니다.\n${issuanceUserErrorMessage(e)}',
                  ),
                ),
              ),
              data: (rows) {
                _maybeOpenPendingDetail(rows);
                _initAssigneeFilterIfNeeded(rows);
                if (rows.isEmpty) {
                  return _emptyScrollable(_emptyMessage(), scheme);
                }
                final filtered = _applyAssigneeFilter(rows);
                final showFilterBar =
                    widget.kind == IssuanceListKind.partial && _isTax;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showFilterBar) _buildAssigneeFilterBar(rows, scheme),
                    Expanded(
                      child: filtered.isEmpty
                          ? _emptyScrollable(
                              '선택한 담당자의 부분발급 건이 없습니다.',
                              scheme,
                            )
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: _buildListBody(filtered, scheme),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DomainTab extends StatelessWidget {
  const _DomainTab({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : accent,
            ),
          ),
        ),
      ),
    );
  }
}
