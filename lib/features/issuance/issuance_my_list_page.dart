import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_card.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/issuance_tax_issue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IssuanceMyListKind { pending, issued }

/// 내가 요청한 대기·발급됨 목록. 현장명 검색 가능.
class IssuanceMyListPage extends ConsumerStatefulWidget {
  const IssuanceMyListPage({
    super.key,
    required this.initialKind,
    this.openMasterId,
    this.openIssueId,
    this.openDomain,
  });

  final IssuanceMyListKind initialKind;
  final String? openMasterId;
  final String? openIssueId;
  final IssuanceDomain? openDomain;

  @override
  ConsumerState<IssuanceMyListPage> createState() => _IssuanceMyListPageState();
}

class _IssuanceMyListPageState extends ConsumerState<IssuanceMyListPage> {
  late IssuanceMyListKind _kind;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _openedPendingDetail = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    final name = row.domain == IssuanceDomain.taxInvoice
        ? (row.master['customer_name'] ?? row.title).toString()
        : (row.master['company_name'] ?? row.title).toString();
    final reason = await showIssuanceCancelDialog(context, targetName: name);
    if (!mounted || reason == null || reason.trim().isEmpty) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발급요청이 취소되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(issuanceUserErrorMessage(e))),
      );
    }
  }

  Future<void> _refresh() async {
    invalidateIssuanceCore(ref);
    await Future.wait([
      ref.read(issuanceMyRequestRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(
        issuanceMyRequestRowsProvider(IssuanceDomain.performanceBond).future,
      ),
      ref.read(issuanceMyIssuedRowsProvider(IssuanceDomain.taxInvoice).future),
      ref.read(
        issuanceMyIssuedRowsProvider(IssuanceDomain.performanceBond).future,
      ),
    ]);
  }

  List<IssuanceRequestRow> _mergedRows({
    required List<IssuanceRequestRow> tax,
    required List<IssuanceRequestRow> bond,
  }) {
    final merged = [...tax, ...bond]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_query.trim().isEmpty) return merged;
    return merged
        .where((row) => issuanceRowMatchesQuery(row, _query))
        .toList();
  }

  void _maybeOpenCreatedRow(List<IssuanceRequestRow> rows) {
    if (_openedPendingDetail || !mounted) return;
    final masterId = widget.openMasterId;
    if (masterId == null || masterId.isEmpty) return;
    final target = findIssuanceRowByIds(
      rows,
      masterId: masterId,
      issueId: widget.openIssueId,
    );
    if (target == null) return;
    _openedPendingDetail = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showIssuanceRequestDetail(context, target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingTax = ref.watch(
      issuanceMyRequestRowsProvider(IssuanceDomain.taxInvoice),
    );
    final pendingBond = ref.watch(
      issuanceMyRequestRowsProvider(IssuanceDomain.performanceBond),
    );
    final issuedTax = ref.watch(
      issuanceMyIssuedRowsProvider(IssuanceDomain.taxInvoice),
    );
    final issuedBond = ref.watch(
      issuanceMyIssuedRowsProvider(IssuanceDomain.performanceBond),
    );

    final pendingRows = _mergedRows(
      tax: pendingTax.valueOrNull ?? const [],
      bond: pendingBond.valueOrNull ?? const [],
    );
    final issuedRows = _mergedRows(
      tax: issuedTax.valueOrNull ?? const [],
      bond: issuedBond.valueOrNull ?? const [],
    );
    final visible = _kind == IssuanceMyListKind.pending
        ? pendingRows
        : issuedRows;

    final loading =
        (_kind == IssuanceMyListKind.pending &&
            (pendingTax.isLoading || pendingBond.isLoading) &&
            pendingTax.valueOrNull == null &&
            pendingBond.valueOrNull == null) ||
        (_kind == IssuanceMyListKind.issued &&
            (issuedTax.isLoading || issuedBond.isLoading) &&
            issuedTax.valueOrNull == null &&
            issuedBond.valueOrNull == null);
    final hasError = _kind == IssuanceMyListKind.pending
        ? pendingTax.hasError || pendingBond.hasError
        : issuedTax.hasError || issuedBond.hasError;

    _maybeOpenCreatedRow([...pendingRows, ...issuedRows]);

    return Scaffold(
      appBar: AppBar(
        title: Text(_kind == IssuanceMyListKind.pending ? '내 대기' : '내 발급됨'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: SegmentedButton<IssuanceMyListKind>(
              segments: [
                ButtonSegment(
                  value: IssuanceMyListKind.pending,
                  label: Text('대기 ${pendingRows.length}'),
                  icon: const Icon(Icons.hourglass_top_rounded, size: 16),
                ),
                ButtonSegment(
                  value: IssuanceMyListKind.issued,
                  label: Text('발급됨 ${issuedRows.length}'),
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (next) {
                HapticFeedback.selectionClick();
                setState(() => _kind = next.first);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '현장명·업체명·번호 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '지우기',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: loading
                  ? const AppLoading(message: '내 요청을 불러오는 중…')
                  : hasError
                  ? issuanceListErrorScrollable(
                      message: '내 요청 목록을 불러오지 못했습니다.',
                      onRetry: _refresh,
                    )
                  : visible.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        AppEmpty(
                          message: _query.trim().isEmpty
                              ? (_kind == IssuanceMyListKind.pending
                                    ? '대기 중인 내 요청이 없습니다.'
                                    : '발급된 내 요청이 없습니다.')
                              : '"$_query"에 해당하는 내 요청이 없습니다.',
                          icon: Icons.inbox_outlined,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final row = visible[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              IssuanceRequestCard(
                                row: row,
                                isOwn: true,
                                large: true,
                                onTap: () =>
                                    showIssuanceRequestDetail(context, row),
                              ),
                              IssuanceRowActions(
                                row: row,
                                onIssue: _openTaxIssueSheet,
                                onCancel: _cancelRow,
                                onOpenDetail: () =>
                                    showIssuanceRequestDetail(context, row),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
