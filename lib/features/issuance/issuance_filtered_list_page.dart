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

  Future<void> _refresh() async {
    ref.invalidate(issuanceAllRowsProvider(_domain));
    ref.invalidate(issuanceCancelledRowsProvider(_domain));
    ref.invalidate(issuanceRequestBadgeCountProvider);
    ref.invalidate(issuanceRequestTotalBadgeCountProvider);
    await ref.read(issuanceAllRowsProvider(_domain).future);
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
    setState(() => _domain = domain);
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

  Widget _sectionHeader(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
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
        separatorBuilder: (_, index) => const SizedBox(height: 10),
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
    final children = <Widget>[];
    if (split.mine.isNotEmpty) {
      children.add(_sectionHeader('내 발급요청', split.mine.length, Colors.blue.shade700));
      for (final row in split.mine) {
        children.add(_buildRowTile(row, isOwn: true));
        children.add(const SizedBox(height: 10));
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
        children.add(_buildRowTile(split.others[i], isOwn: false));
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
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDomainSwitcher(scheme),
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
                if (rows.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _emptyMessage(),
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
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildListBody(rows, scheme),
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
