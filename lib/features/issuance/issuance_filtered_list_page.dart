import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_card.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_tax_issue_sheet.dart';
import 'package:coad_customer_calls/features/issuance/tax_invoice_issue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 발급대기 / 부분발급 / 전체 전용 전체 화면 목록.
class IssuanceFilteredListPage extends ConsumerStatefulWidget {
  const IssuanceFilteredListPage({
    required this.domain,
    required this.kind,
    super.key,
  });

  final IssuanceDomain domain;
  final IssuanceListKind kind;

  @override
  ConsumerState<IssuanceFilteredListPage> createState() =>
      _IssuanceFilteredListPageState();
}

class _IssuanceFilteredListPageState
    extends ConsumerState<IssuanceFilteredListPage> {
  late IssuanceDomain _domain;

  @override
  void initState() {
    super.initState();
    _domain = widget.domain;
  }

  bool get _isTax => _domain == IssuanceDomain.taxInvoice;

  Future<void> _refresh() async {
    ref.invalidate(issuanceAllRowsProvider(_domain));
    ref.invalidate(issuanceRequestBadgeCountProvider);
    await ref.read(issuanceAllRowsProvider(_domain).future);
  }

  AsyncValue<List<IssuanceRequestRow>> _rowsAsync() {
    switch (widget.kind) {
      case IssuanceListKind.request:
        return ref.watch(issuanceRequestRowsProvider(_domain));
      case IssuanceListKind.partial:
        return ref.watch(issuancePartialRowsProvider(_domain));
      case IssuanceListKind.all:
        return ref.watch(issuanceAllTabRowsProvider(_domain));
    }
  }

  Future<void> _openTaxIssueSheet(
    IssuanceRequestRow row,
    TaxIssueSheetMode mode,
  ) async {
    final ok = await showTaxInvoiceIssueSheet(
      context: context,
      row: row,
      mode: mode,
    );
    if (ok == true && mounted) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == TaxIssueSheetMode.insertRequest
                ? '발급요청이 등록되었습니다.'
                : '발급이 완료되었습니다.',
          ),
        ),
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

  String _emptyMessage() {
    final domain = _isTax ? '세금계산서' : '이행증권';
    return switch (widget.kind) {
      IssuanceListKind.request => '$domain 발급대기 건이 없습니다.',
      IssuanceListKind.partial =>
        _isTax ? '부분발급 대상이 없습니다.' : '이행증권은 부분발급 목록을 사용하지 않습니다.',
      IssuanceListKind.all => '$domain 발급 건이 없습니다.',
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
            child: Text(
              meta.subtitle,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: rowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('목록을 불러오지 못했습니다.\n$e'),
                ),
              ),
              data: (rows) {
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
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IssuanceRequestCard(
                            row: row,
                            onTap: () =>
                                showIssuanceRequestDetail(context, row),
                          ),
                          if (widget.kind == IssuanceListKind.request ||
                              widget.kind == IssuanceListKind.partial)
                            IssuanceTaxRowActions(
                              row: row,
                              onIssue: _openTaxIssueSheet,
                            ),
                        ],
                      );
                    },
                  ),
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
