import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
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
    if (_notesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문 내용을 입력해 주세요.')));
      return;
    }
    if (_paid && _amount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('유상이면 금액을 입력해 주세요.')));
      return;
    }
    if (!_completed && (_nextVisitYmd == null || _nextVisitYmd!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('미완료이면 다음 방문일을 선택해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(authControllerProvider);
      final paid = _paid && _amount != null;
      await ref
          .read(supportCallLogRepositoryProvider)
          .addVisitReport(
            callLogId: widget.log.id,
            report: SupportVisitReport(
              visitYmd: _visitYmd,
              completed: _completed,
              paid: paid,
              amount: paid ? _amount : null,
              depositYmd: paid ? _depositYmd : null,
              parts: List.of(_parts),
              photoUrls: _completed ? List.of(_photos) : const [],
              nextVisitYmd: _completed ? null : _nextVisitYmd,
              notes: _notesCtrl.text.trim(),
              createdBy: user?.name ?? user?.id,
            ),
          );
      ref.invalidate(supportHomeStatsProvider);
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
              '${widget.log.customerName} · 현장 방문 내용이 접수에 남습니다',
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
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('완료'),
                  selected: _completed,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _completed = true),
                ),
                ChoiceChip(
                  label: const Text('미완료 · 재방문'),
                  selected: !_completed,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _completed = false),
                ),
              ],
            ),
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
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('무상'),
                  selected: !_paid,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _paid = false),
                ),
                ChoiceChip(
                  label: const Text('유상'),
                  selected: _paid,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _paid = true),
                ),
              ],
            ),
            if (_paid) ...[
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
                  _depositYmd == null ? '선택 (선택 사항)' : _ymdLabel(_depositYmd!),
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
            ],
            const SizedBox(height: 8),
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
                        final ymd = await _pickYmd(
                          _nextVisitYmd ?? todayYmdSeoul(),
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
                      : const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
