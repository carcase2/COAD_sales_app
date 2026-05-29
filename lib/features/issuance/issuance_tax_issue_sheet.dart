import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/issuance/tax_invoice_issue_service.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<bool?> showTaxInvoiceIssueSheet({
  required BuildContext context,
  required IssuanceRequestRow row,
  required TaxIssueSheetMode mode,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TaxInvoiceIssueSheet(row: row, mode: mode),
  );
}

class _TaxInvoiceIssueSheet extends ConsumerStatefulWidget {
  const _TaxInvoiceIssueSheet({required this.row, required this.mode});

  final IssuanceRequestRow row;
  final TaxIssueSheetMode mode;

  @override
  ConsumerState<_TaxInvoiceIssueSheet> createState() =>
      _TaxInvoiceIssueSheetState();
}

class _TaxInvoiceIssueSheetState extends ConsumerState<_TaxInvoiceIssueSheet> {
  final _itemName = TextEditingController();
  final _pct = TextEditingController();
  String _itemType = '선급금';
  PlatformFile? _image;
  bool _saving = false;

  bool get _needsImage => widget.mode != TaxIssueSheetMode.insertRequest;

  String get _title => switch (widget.mode) {
    TaxIssueSheetMode.insertRequest => '발급요청 등록',
    TaxIssueSheetMode.fulfillRequest => '발급 (발급요청 처리)',
    TaxIssueSheetMode.remainderIssue => '잔금 발급',
  };

  @override
  void initState() {
    super.initState();
    final m = widget.row.master;
    _itemName.text = (m['item_name'] ?? '셔터').toString();
    _itemType = (m['item_type'] ?? '선급금').toString();
    if (widget.mode == TaxIssueSheetMode.insertRequest ||
        widget.mode == TaxIssueSheetMode.remainderIssue) {
      _pct.text = widget.row.remainingPct.round().toString();
    } else {
      final issuePct = widget.row.issue?['percentage'];
      final p = issuePct is num
          ? issuePct.toDouble()
          : double.tryParse('$issuePct') ?? 100;
      _pct.text = p.round().toString();
    }
  }

  @override
  void dispose() {
    _itemName.dispose();
    _pct.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    setState(() => _image = f);
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
    if (_needsImage && _image == null) {
      _snack('세금계산서 이미지를 첨부해주세요.');
      return;
    }

    final invoiceId = widget.row.master['id']?.toString();
    if (invoiceId == null || invoiceId.isEmpty) {
      _snack('세금계산서 ID가 없습니다.');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = TaxInvoiceIssueService();
      if (widget.mode == TaxIssueSheetMode.insertRequest) {
        await service.insertPartialRequestIssue(
          invoiceId: invoiceId,
          issuePercentage: pct,
          issuedBy: user.name,
          itemType: _itemType,
          itemName: _itemName.text.trim(),
        );
      } else {
        await service.completeIssue(
          invoiceId: invoiceId,
          mode: widget.mode,
          imageFile: _image!,
          issuedBy: user.name,
          itemType: _itemType,
          itemName: _itemName.text.trim(),
          issuePercentage: pct,
          targetIssueId: widget.row.issue?['id']?.toString(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack('처리 실패: $e');
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
            _title,
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
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _itemType,
            decoration: const InputDecoration(
              labelText: '항목',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '선급금', child: Text('선급금')),
              DropdownMenuItem(value: '중도금', child: Text('중도금')),
              DropdownMenuItem(value: '잔금', child: Text('잔금')),
            ],
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) setState(() => _itemType = v);
                  },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _itemName,
            decoration: const InputDecoration(
              labelText: '품목명',
              border: OutlineInputBorder(),
            ),
            enabled: !_saving,
          ),
          if (widget.mode != TaxIssueSheetMode.fulfillRequest) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _pct,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: widget.mode == TaxIssueSheetMode.insertRequest
                    ? '발급요청 비율 (%)'
                    : '이번 발급 비율 (%)',
                border: const OutlineInputBorder(),
              ),
              enabled: !_saving,
            ),
          ],
          if (_needsImage) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(_image == null ? '세금계산서 사진 선택' : _image!.name),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.mode == TaxIssueSheetMode.insertRequest
                        ? '발급요청 등록'
                        : '발급 완료',
                  ),
          ),
        ],
      ),
    );
  }
}
