import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
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
    // Android 네비는 하단 고정 버튼 SafeArea에서 처리.
    useSafeArea: false,
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
  bool _saving = false;
  bool _completed = true;
  bool _paid = false;
  late final String? _scheduledYmd;
  late final String? _scheduledTime;
  late String _visitYmd;
  String? _depositYmd;
  bool _depositPaid = false;
  String? _depositPaidYmd;
  String? _nextVisitYmd;
  String? _nextVisitTeamId;
  String? _nextVisitTeamLabel;
  String? _nextVisitTime;
  String? _visitTime;
  final List<String> _quoteParts = [];
  final List<String> _extraParts = [];
  final List<String> _photos = [];
  bool _uploadBusy = false;
  SupportQuoteDocument? _quote;
  bool _quoteLoading = true;
  Object? _quoteError;

  List<String> get _parts => [..._quoteParts, ..._extraParts];

  @override
  void initState() {
    super.initState();
    final scheduled = (widget.log.visitDate ?? '').trim();
    _scheduledYmd = scheduled.isEmpty ? null : scheduled;
    final scheduledTime = (widget.log.visitTime ?? '').trim();
    _scheduledTime = scheduledTime.isEmpty
        ? null
        : (scheduledTime.length >= 5
              ? scheduledTime.substring(0, 5)
              : scheduledTime);
    // 실제 방문은 기본으로 오늘 — 예정과 다르면 바로 고친다.
    _visitYmd = todayYmdSeoul();
    _visitTime = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadQuote());
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _ymdLabel(String ymd) {
    if (ymd.length < 10) return ymd;
    final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
    final d = int.tryParse(ymd.substring(8, 10)) ?? 0;
    return '$m/$d';
  }

  TimeOfDay _visitTimeOfDay() {
    final raw = (_visitTime ?? '').trim();
    if (raw.length >= 5) {
      final h = int.tryParse(raw.substring(0, 2));
      final m = int.tryParse(raw.substring(3, 5));
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return TimeOfDay.now();
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

  Future<void> _pickActualVisitDateTime() async {
    final initialDate = DateTime.tryParse(_visitYmd) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '실제 방문일',
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _visitTimeOfDay(),
      helpText: '실제 방문 시간',
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _visitYmd =
          '${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      _visitTime =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _loadQuote() async {
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });
    try {
      final site = parseSupportIssueBody(widget.log.issue).siteName.trim();
      final quotes = await ref
          .read(supportAsQuoteRepositoryProvider)
          .listForSite(
            phone: widget.log.customerPhone,
            site: site.isEmpty ? null : site,
            customerName: widget.log.customerName,
            callLogId: widget.log.id,
          );
      if (!mounted) return;
      final picked = pickSupportQuoteForVisitReport(
        quotes,
        callLogId: widget.log.id,
      );
      setState(() {
        _quoteLoading = false;
        if (picked != null) {
          _applyQuote(picked, forceNotes: true);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quoteLoading = false;
        _quoteError = e;
      });
    }
  }

  void _applyQuote(SupportQuoteDocument doc, {bool forceNotes = false}) {
    _quote = doc;
    _quoteParts
      ..clear()
      ..addAll(supportQuotePartNames(doc));
    if (forceNotes || _notesCtrl.text.trim().isEmpty) {
      _notesCtrl.text = supportQuoteConsultBody(doc);
    }
    _fillAmountFromQuoteIfNeeded();
  }

  void _fillAmountFromQuoteIfNeeded() {
    final quote = _quote;
    if (!_completed || !_paid || quote == null || quote.total <= 0) return;
    if (_amountCtrl.text.trim().isNotEmpty) return;
    _amountCtrl.text = formatSupportConsultAmountGrouped('${quote.total}');
  }

  void _insertExtraUnitPrice(SupportUnitPriceItem item) {
    final name = item.name.trim();
    final added =
        name.isNotEmpty &&
        !_quoteParts.contains(name) &&
        !_extraParts.contains(name);
    if (added) {
      _extraParts.add(name);
    }
    final price = item.price ?? 0;
    if (_completed && _paid && price > 0) {
      final current =
          int.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
      if (added || _amountCtrl.text.trim().isEmpty) {
        final next = added ? current + price : price;
        _amountCtrl.text = formatSupportConsultAmountGrouped('$next');
      }
    }
    final line = '추가 · ${supportUnitPriceInsertLine(item)}';
    final cur = _notesCtrl.text.trim();
    _notesCtrl.text = cur.isEmpty ? line : '$cur\n$line';
    setState(() {});
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
      visitTime: _visitTime,
      scheduledYmd: _scheduledYmd,
      scheduledTime: _scheduledTime,
      completed: _completed,
      paid: paid,
      amount: paid ? _amount : null,
      depositYmd: paid ? _depositYmd : null,
      depositPaid: paid && _depositPaid,
      depositPaidYmd: paid && _depositPaid
          ? (_depositPaidYmd ?? todayYmdSeoul())
          : null,
      parts: List.of(_parts),
      photoUrls: _completed ? List.of(_photos) : const [],
      nextVisitYmd: _completed ? null : _nextVisitYmd,
      nextVisitTeamId: _completed ? null : _nextVisitTeamId,
      nextVisitTime: _completed ? null : _nextVisitTime,
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
    final writer = ref.watch(authControllerProvider)?.name.trim() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '방문 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.log.customerName} · 완료하면 유무상·입금을 챙기고, 미완료면 다음 방문일을 잡습니다',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
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
                    if ((_scheduledYmd ?? '').isNotEmpty) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.event_note_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                        title: const Text('방문예정'),
                        subtitle: Text(
                          [
                            _ymdLabel(_scheduledYmd!),
                            if ((_scheduledTime ?? '').isNotEmpty)
                              _scheduledTime!,
                          ].join(' · '),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_rounded),
                      title: const Text('실제 방문일·시간'),
                      subtitle: Text(
                        [
                          _ymdLabel(_visitYmd),
                          if ((_visitTime ?? '').isNotEmpty) _visitTime!,
                          if ((_visitTime ?? '').isEmpty) '달력·시계에서 선택',
                          if (_visitYmd == todayYmdSeoul()) '오늘',
                          if ((_scheduledYmd ?? '').isNotEmpty &&
                              (_scheduledYmd != _visitYmd ||
                                  ((_scheduledTime ?? '') !=
                                      (_visitTime ?? ''))))
                            '예정과 다름',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.schedule_rounded),
                      onTap: _saving ? null : _pickActualVisitDateTime,
                    ),
                    const SizedBox(height: 8),
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
                          ? '완료면 유무상을 고르고, 유상이면 금액·입금예정일·입금일을 남깁니다.'
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
                            onTap: () => setState(() {
                              _paid = true;
                              _fillAmountFromQuoteIfNeeded();
                            }),
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
                        inputFormatters: const [
                          _VisitAmountThousandsFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: '금액',
                          hintText: '0',
                          suffixText: '원',
                          filled: true,
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
                                if (ymd != null) {
                                  setState(() => _depositYmd = ymd);
                                }
                              },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _depositPaid,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                _depositPaid = v ?? false;
                                if (_depositPaid) {
                                  _depositPaidYmd ??= todayYmdSeoul();
                                } else {
                                  _depositPaidYmd = null;
                                }
                              }),
                        title: const Text('입금완료'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_depositPaid)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.event_available_rounded,
                          ),
                          title: const Text('입금일'),
                          subtitle: Text(
                            _depositPaidYmd == null
                                ? '실제로 들어온 날'
                                : _ymdLabel(_depositPaidYmd!),
                          ),
                          trailing: const Icon(Icons.event_rounded),
                          onTap: _saving
                              ? null
                              : () async {
                                  final ymd = await _pickYmd(
                                    _depositPaidYmd ??
                                        _depositYmd ??
                                        todayYmdSeoul(),
                                  );
                                  if (ymd != null) {
                                    setState(() => _depositPaidYmd = ymd);
                                  }
                                },
                        ),
                    ],
                    const SizedBox(height: 8),
                    if (_quoteLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else if (_quoteError != null)
                      Text(
                        '견적서를 불러오지 못했습니다. ${koreanErrorMessage(_quoteError!)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else if (_quote != null) ...[
                      Text(
                        '발송 견적서',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Material(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                supportQuoteHistoryLine(_quote!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              if (_quote!.lines.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                for (final line in _quote!.lines)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      [
                                        supportQuoteKindLabel(line.kind),
                                        line.name.trim(),
                                        if (line.spec.trim().isNotEmpty)
                                          line.spec.trim(),
                                        if (line.qty > 0)
                                          '${line.qty}${line.unit.trim()}',
                                        if (line.amount > 0)
                                          '${NumberFormat('#,###').format(line.amount)}원',
                                      ].where((e) => e.isNotEmpty).join(' · '),
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                              ],
                              if (_quoteParts.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final name in _quoteParts)
                                      Chip(
                                        label: Text(name),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                  ],
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(
                                          () => _applyQuote(
                                            _quote!,
                                            forceNotes: true,
                                          ),
                                        ),
                                  child: const Text('견적 내용 다시 넣기'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '추가 부품 · 인건비',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '견적서에 없는 것만 A/S 단가표에서 추가합니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SupportUnitPriceOpenTile(
                        subtitle: '견적 외 품목만 고르면 됩니다',
                        insertLabel: '추가로 넣기',
                        onInsert: _insertExtraUnitPrice,
                      ),
                      if (_extraParts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < _extraParts.length; i++)
                              InputChip(
                                label: Text(_extraParts[i]),
                                onDeleted: _saving
                                    ? null
                                    : () => setState(
                                        () => _extraParts.removeAt(i),
                                      ),
                              ),
                          ],
                        ),
                      ],
                    ] else ...[
                      Text(
                        '정식 견적서',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이 현장 발송 견적서가 없습니다. A/S 단가표로 방문에 쓴 품목을 넣으세요.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SupportUnitPriceOpenTile(
                        subtitle: '품명 · 금액을 고르면 방문 내용에 넣습니다',
                        insertLabel: '기록에 넣기',
                        onInsert: _insertExtraUnitPrice,
                      ),
                      if (_extraParts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < _extraParts.length; i++)
                              InputChip(
                                label: Text(_extraParts[i]),
                                onDeleted: _saving
                                    ? null
                                    : () => setState(
                                        () => _extraParts.removeAt(i),
                                      ),
                              ),
                          ],
                        ),
                      ],
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
                        onPressed:
                            _saving || _uploadBusy ? null : _pickPhotos,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          _uploadBusy ? '사진 올리는 중…' : '완료 사진 추가',
                        ),
                      ),
                      if (_photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SalesCallAttachmentsStrip(
                          urls: _photos,
                          saveNamePrefix: widget.log.customerName,
                          editable: !_saving,
                          onRemoveAt: (i) =>
                              setState(() => _photos.removeAt(i)),
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
                              ? '날짜·팀·시간을 선택해 주세요'
                              : [
                                  _ymdLabel(_nextVisitYmd!),
                                  if ((_nextVisitTime ?? '').isNotEmpty)
                                    _nextVisitTime!,
                                  if ((_nextVisitTeamLabel ?? '').isNotEmpty)
                                    _nextVisitTeamLabel!,
                                ].join(' · '),
                        ),
                        trailing: const Icon(Icons.event_rounded),
                        onTap: _saving
                            ? null
                            : () async {
                                final picked =
                                    await showSupportVisitDatePicker(
                                      context,
                                      log: widget.log,
                                      selectedYmd: _nextVisitYmd,
                                      selectedTeamId: _nextVisitTeamId,
                                      selectedTime: _nextVisitTime,
                                    );
                                if (picked != null) {
                                  setState(() {
                                    _nextVisitYmd = picked.ymd;
                                    _nextVisitTeamId = picked.teamId;
                                    _nextVisitTeamLabel = picked.teamLabel;
                                    _nextVisitTime = picked.time;
                                  });
                                }
                              },
                      ),
                  ],
                ),
              ),
            ),
            Material(
              elevation: 3,
              color: scheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _completed
                                    ? (_paid
                                          ? '완료 · 입금예정 저장'
                                          : '완료 저장')
                                    : '재방문 저장',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
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

class _VisitAmountThousandsFormatter extends TextInputFormatter {
  const _VisitAmountThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final grouped = formatSupportConsultAmountGrouped(newValue.text);
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: grouped.length),
    );
  }
}
