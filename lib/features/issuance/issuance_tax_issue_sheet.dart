import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/tax_invoice_issue_service.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool?> showTaxInvoiceIssueSheet({
  required BuildContext context,
  required IssuanceRequestRow row,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TaxInvoiceIssueSheet(row: row),
  );
}

class _TaxInvoiceIssueSheet extends ConsumerStatefulWidget {
  const _TaxInvoiceIssueSheet({required this.row});

  final IssuanceRequestRow row;

  @override
  ConsumerState<_TaxInvoiceIssueSheet> createState() =>
      _TaxInvoiceIssueSheetState();
}

class _TaxInvoiceIssueSheetState extends ConsumerState<_TaxInvoiceIssueSheet> {
  final _itemName = TextEditingController();
  final _pct = TextEditingController();
  String _itemType = '선급금';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.row.master;
    _itemName.text = (m['item_name'] ?? '셔터').toString();
    _itemType = (m['item_type'] ?? '선급금').toString();
    _pct.text = widget.row.remainingPct.round().toString();
  }

  @override
  void dispose() {
    _itemName.dispose();
    _pct.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final user = ref.read(authControllerProvider);
    if (user == null) {
      _snack('로그인 정보가 필요합니다.');
      return;
    }
    if (_itemType.trim().isEmpty) {
      _snack('항목을 선택해주세요.');
      return;
    }
    if (_itemName.text.trim().isEmpty) {
      _snack('품목명을 입력해주세요.');
      return;
    }
    final pct = double.tryParse(_pct.text.trim());
    if (pct == null || pct <= 0 || pct > 100) {
      _snack('발급 비율(1~100)을 확인해주세요.');
      return;
    }

    final invoiceId = widget.row.master['id']?.toString();
    if (invoiceId == null || invoiceId.isEmpty) {
      _snack('세금계산서 ID가 없습니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      final issueId = await TaxInvoiceIssueService().insertPartialRequestIssue(
        invoiceId: invoiceId,
        issuePercentage: pct,
        issuedBy: user.name,
        itemType: _itemType,
        itemName: _itemName.text.trim(),
      );
      try {
        await NotificationService.markIssuanceRequestSeen(
          prefs: ref.read(appDependenciesProvider).prefs,
          domain: IssuanceDomain.taxInvoice,
          masterId: invoiceId,
          issueId: issueId,
        );
      } catch (e) {
        debugPrint('[partial-issuance-request-seen] failed: $e');
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack(issuanceUserErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customer = (widget.row.master['customer_name'] ?? widget.row.title)
        .toString();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '부분 발급요청 등록',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            customer,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
          if (widget.row.isPartial) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.row.remainingPct.round()}% 남음 · 누적 ${widget.row.issuedPct.round()}% 발급',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _itemType,
            items: const [
              '선급금',
              '중도금',
              '잔금',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _itemType = v);
            },
            decoration: const InputDecoration(labelText: '항목 구분 *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _itemName,
            decoration: const InputDecoration(labelText: '품목명 *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pct,
            decoration: const InputDecoration(labelText: '발급 요청 비율(%) *'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '등록 중...' : '발급요청 등록'),
          ),
        ],
      ),
    );
  }
}
