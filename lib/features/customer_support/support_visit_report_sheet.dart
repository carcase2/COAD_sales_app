import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_date_picker.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

Future<bool> showSupportVisitReportSheet(
  BuildContext context, {
  required SupportCallLog log,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SupportVisitReportSheet(log: log),
  );
  return saved == true;
}

class _SupportVisitReportSheet extends ConsumerStatefulWidget {
  const _SupportVisitReportSheet({required this.log});

  final SupportCallLog log;

  @override
  ConsumerState<_SupportVisitReportSheet> createState() =>
      _SupportVisitReportSheetState();
}

class _SupportVisitReportSheetState
    extends ConsumerState<_SupportVisitReportSheet> {
  final _notesCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _partCtrl = TextEditingController();
  bool _saving = false;
  bool _completed = true;
  bool _paid = false;
  late String _visitYmd;
  String? _depositYmd;
  bool _depositPaid = false;
  String? _nextVisitYmd;
  final List<String> _parts = [];
  final List<String> _photos = [];
  bool _uploadBusy = false;

  @override
  void initState() {
    super.initState();
    _visitYmd = (widget.log.visitDate ?? '').trim().isNotEmpty
        ? widget.log.visitDate!
        : todayYmdSeoul();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _amountCtrl.dispose();
    _partCtrl.dispose();
    super.dispose();
  }

  String _ymdLabel(String ymd) {
    if (ymd.length < 10) return ymd;
    final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
    final d = int.tryParse(ymd.substring(8, 10)) ?? 0;
    return '$m/$d';
  }

  Future<String?> _pickYmd(String current) async {
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return null;
    return '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  void _addPart() {
    final v = _partCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _parts.add(v);
      _partCtrl.clear();
    });
  }

  int? get _amount {
    final n = int.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (n == null || n <= 0) return null;
    return n;
  }

  Future<void> _pickPhotos() async {
    final source = await showSalesCallImageSourceSheet(context, title: '완료 사진');
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final paths = <String>[];
    if (source == SalesCallImageSource.camera) {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot != null) paths.add(shot.path);
    } else {
      final shots = await picker.pickMultiImage(imageQuality: 85);
      paths.addAll(shots.map((e) => e.path));
    }
    if (paths.isEmpty || !mounted) return;
    setState(() => _uploadBusy = true);
    final uploader = ref.read(b2UploadRepositoryProvider);
    try {
      for (final path in paths) {
        try {
          final url = await uploader.uploadSupportCallFile(
            filePath: path,
            customerPhone: widget.log.customerPhone,
          );
          if (!mounted) return;
          setState(() => _photos.add(url));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
        }
      }
    } finally {
      if (mounted) setState(() => _uploadBusy = false);
    }
  }

  Future<void> _save() async {
    final paid = _completed && _paid;
    final report = SupportVisitReport(
      visitYmd: _visitYmd,
      completed: _completed,
      paid: paid,
      amount: paid ? _amount : null,
      depositYmd: paid ? _depositYmd : null,
      depositPaid: paid && _depositPaid,
      parts: List.of(_parts),
      photoUrls: _completed ? List.of(_photos) : const [],
      nextVisitYmd: _completed ? null : _nextVisitYmd,
      notes: _notesCtrl.text.trim(),
      createdBy:
          ref.read(authControllerProvider)?.name ??
          ref.read(authControllerProvider)?.id,
    );
    final issue = supportVisitReportIssue(report);
    if (issue != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(issue)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(supportCallLogRepositoryProvider)
          .addVisitReport(callLogId: widget.log.id, report: report);
      invalidateSupportWorkCaches(ref);
      unawaited(refreshSupportDueReminders(ref));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom + media.padding.bottom;
    final writer = ref.watch(authControllerProvider)?.name.trim() ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '방문 기록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.log.customerName} · 완료하면 유무상·입금을 챙기고, 미완료면 다음 방문일을 잡습니다',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            if (writer.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '작성 $writer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_rounded),
              title: const Text('방문일'),
              subtitle: Text(_ymdLabel(_visitYmd)),
              trailing: const Icon(Icons.event_rounded),
              onTap: _saving
                  ? null
                  : () async {
                      final ymd = await _pickYmd(_visitYmd);
                      if (ymd != null) setState(() => _visitYmd = ymd);
                    },
            ),
            const SizedBox(height: 4),
            Text(
              '완료 여부',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _FlowChip(
                    label: '완료',
                    selected: _completed,
                    color: AppTokens.success(scheme),
                    enabled: !_saving,
                    onTap: () => setState(() => _completed = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FlowChip(
                    label: '미완료 · 재방문',
                    selected: !_completed,
                    color: scheme.error,
                    enabled: !_saving,
                    onTap: () => setState(() => _completed = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _completed
                  ? '완료면 유무상을 고르고, 유상이면 금액·입금예정일로 입금을 챙깁니다.'
                  : '끝나지 않았으면 다음 방문일을 잡고 다시 방문합니다.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            if (_completed) ...[
              const SizedBox(height: 12),
              Text(
                '유상 / 무상',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _FlowChip(
                      label: '무상',
                      selected: !_paid,
                      color: scheme.primary,
                      enabled: !_saving,
                      onTap: () => setState(() => _paid = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FlowChip(
                      label: '유상',
                      selected: _paid,
                      color: const Color(0xFFD97706),
                      enabled: !_saving,
                      onTap: () => setState(() => _paid = true),
                    ),
                  ),
                ],
              ),
            ],
            if (_completed && _paid) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '금액',
                  hintText: '숫자만',
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_amount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${NumberFormat('#,###').format(_amount)}원',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments_outlined),
                title: const Text('입금예정일'),
                subtitle: Text(
                  _depositYmd == null
                      ? '달력에서 입금을 챙기려면 날짜를 선택'
                      : _ymdLabel(_depositYmd!),
                ),
                trailing: const Icon(Icons.event_rounded),
                onTap: _saving
                    ? null
                    : () async {
                        final ymd = await _pickYmd(
                          _depositYmd ?? todayYmdSeoul(),
                        );
                        if (ymd != null) setState(() => _depositYmd = ymd);
                      },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _depositPaid,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _depositPaid = v ?? false),
                title: const Text('입금완료'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            const SizedBox(height: 8),
            SupportUnitPriceOpenTile(
              subtitle: '방문 중 품명 · 금액 검색. 고르면 부품·내용에 넣습니다',
              insertLabel: '기록에 넣기',
              onInsert: (item) {
                final name = item.name.trim();
                if (name.isNotEmpty && !_parts.contains(name)) {
                  _parts.add(name);
                }
                if (_completed &&
                    _paid &&
                    item.price != null &&
                    _amountCtrl.text.trim().isEmpty) {
                  _amountCtrl.text = '${item.price}';
                }
                final line = supportUnitPriceInsertLine(item);
                final cur = _notesCtrl.text.trim();
                _notesCtrl.text = cur.isEmpty ? line : '$cur\n$line';
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Text(
              '추가 부품',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _partCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      hintText: '부품명',
                      filled: true,
                    ),
                    onSubmitted: (_) => _addPart(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _addPart,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _parts.length; i++)
                    InputChip(
                      label: Text(_parts[i]),
                      onDeleted: _saving
                          ? null
                          : () => setState(() => _parts.removeAt(i)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              minLines: 3,
              maxLines: 6,
              enabled: !_saving,
              decoration: const InputDecoration(
                hintText: '방문 내용을 입력해 주세요',
                filled: true,
              ),
            ),
            if (_completed) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving || _uploadBusy ? null : _pickPhotos,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_uploadBusy ? '사진 올리는 중…' : '완료 사진 추가'),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                SalesCallAttachmentsStrip(
                  urls: _photos,
                  saveNamePrefix: widget.log.customerName,
                  editable: !_saving,
                  onRemoveAt: (i) => setState(() => _photos.removeAt(i)),
                ),
              ],
            ],
            if (!_completed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_repeat_rounded),
                title: const Text('다음 방문일'),
                subtitle: Text(
                  _nextVisitYmd == null
                      ? '날짜를 선택해 주세요'
                      : _ymdLabel(_nextVisitYmd!),
                ),
                trailing: const Icon(Icons.event_rounded),
                onTap: _saving
                    ? null
                    : () async {
                        final ymd = await showSupportVisitDatePicker(
                          context,
                          log: widget.log,
                          selectedYmd: _nextVisitYmd,
                        );
                        if (ymd != null) setState(() => _nextVisitYmd = ymd);
                      },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          unawaited(_save());
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _completed
                              ? (_paid ? '완료 · 입금예정 저장' : '완료 저장')
                              : '재방문 저장',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected
            ? color
            : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? color
                : scheme.outlineVariant.withValues(alpha: 0.75),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
