import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_date_picker.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 접수 직후·상세에서 N차 상담. 결과에 따라 미처리에서 빠진다.
Future<bool> showSupportFirstConsultationSheet(
  BuildContext context, {
  required SupportCallLog log,
  int stage = 1,
  SupportConsultOutcome? lastOutcome,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    // Android 네비는 하단 고정 버튼 SafeArea에서 처리.
    useSafeArea: false,
    builder: (_) => _SupportFirstConsultationSheet(
      log: log,
      stage: stage,
      lastOutcome: lastOutcome,
    ),
  );
  return saved == true;
}

class _SupportFirstConsultationSheet extends ConsumerStatefulWidget {
  const _SupportFirstConsultationSheet({
    required this.log,
    required this.stage,
    this.lastOutcome,
  });

  final SupportCallLog log;
  final int stage;
  final SupportConsultOutcome? lastOutcome;

  @override
  ConsumerState<_SupportFirstConsultationSheet> createState() =>
      _SupportFirstConsultationSheetState();
}

class _SupportFirstConsultationSheetState
    extends ConsumerState<_SupportFirstConsultationSheet> {
  final _ctrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;
  SupportConsultOutcome? _outcome;
  late String _sendYmd;
  String? _visitYmd;
  String? _visitTeamId;
  String? _visitTeamLabel;
  String? _visitTime;
  SupportQuoteDocument? _quoteDoc;
  String? _quoteConsultBlock;

  @override
  void initState() {
    super.initState();
    _sendYmd = todayYmdSeoul();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  int? get _verbalAmount => parseSupportConsultAmountDigits(_amountCtrl.text);

  String _ymdLabel(String ymd) {
    if (ymd.length < 10) return ymd;
    final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
    final d = int.tryParse(ymd.substring(8, 10)) ?? 0;
    return '$m/$d';
  }

  Future<void> _pickDate({required bool visit}) async {
    if (visit) {
      final picked = await showSupportVisitDatePicker(
        context,
        log: widget.log,
        selectedYmd: _visitYmd,
        selectedTeamId: _visitTeamId,
        selectedTime: _visitTime,
        selectedTeamLabel: _visitTeamLabel,
        confirmChange: (_visitYmd ?? '').trim().isNotEmpty,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _visitYmd = picked.ymd;
        _visitTeamId = picked.teamId;
        _visitTeamLabel = picked.teamLabel;
        _visitTime = picked.time;
      });
      return;
    }
    final initial = DateTime.tryParse(_sendYmd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final ymd =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() => _sendYmd = ymd);
  }

  SupportSiteSample _siteFromLog() {
    final log = widget.log;
    return SupportSiteSample(
      id: log.id,
      name: log.customerName.trim(),
      address: log.address ?? '',
      phone: log.customerPhone,
      assignee: log.createdBy ?? '',
      revisitCount: 0,
      installCompletedYmd: null,
      addresses: [
        if ((log.address ?? '').trim().isNotEmpty) log.address!.trim(),
      ],
      history: const [],
      quotes: const [],
      hasBusinessLicense: false,
      hasChecksheet: false,
    );
  }

  void _applyQuoteToConsult(SupportQuoteDocument doc) {
    final summary = supportQuoteConsultBody(doc);
    final cur = _ctrl.text;
    if (_quoteConsultBlock != null && cur.contains(_quoteConsultBlock!)) {
      _ctrl.text = cur.replaceFirst(_quoteConsultBlock!, summary);
    } else if (cur.trim().isEmpty) {
      _ctrl.text = summary;
    } else {
      _ctrl.text = '${cur.trim()}\n$summary';
    }
    _quoteConsultBlock = summary;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  Future<void> _openQuoteWriter() async {
    final draft = await pushSupportQuoteEditor(
      context,
      site: _siteFromLog(),
      callLogId: widget.log.id,
      existing: _quoteDoc,
    );
    if (draft == null || !mounted) return;
    SupportQuoteDocument stored = draft;
    try {
      stored = await ref.read(supportAsQuoteRepositoryProvider).upsert(
        draft,
        editorName: ref.read(authControllerProvider)?.name ??
            ref.read(authControllerProvider)?.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
    if (!mounted) return;
    setState(() {
      _quoteDoc = stored;
      _applyQuoteToConsult(stored);
    });
    await _handleQuoteView(stored);
  }

  Future<void> _openQuoteExport() async {
    final doc = _quoteDoc;
    if (doc == null) return;
    await _handleQuoteView(doc);
  }

  Future<void> _handleQuoteView(SupportQuoteDocument doc) async {
    final action = await showSupportQuoteExportSheet(context, doc: doc);
    if (!mounted) return;
    if (action == SupportQuoteViewAction.edit) {
      await _openQuoteWriter();
      return;
    }
    if (action != SupportQuoteViewAction.sent) return;
    final day = todayYmdSeoul();
    final marked = doc.copyWith(
      sentYmd: day,
      callLogId: widget.log.id,
    );
    try {
      final stored = await ref.read(supportAsQuoteRepositoryProvider).upsert(
        marked,
        editorName: ref.read(authControllerProvider)?.name ??
            ref.read(authControllerProvider)?.id,
      );
      await ref.read(supportCallLogRepositoryProvider).markLatestQuoteSentForCallLog(
        widget.log.id,
        sentYmd: day,
        createdBy: ref.read(authControllerProvider)?.name,
      );
      if (!mounted) return;
      setState(() => _quoteDoc = stored);
    } catch (_) {
      if (!mounted) return;
      setState(() => _quoteDoc = marked);
    }
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (_outcome == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상담 결과를 선택해 주세요.')));
      return;
    }
    if (_outcome == SupportConsultOutcome.visit &&
        (_visitYmd == null || _visitYmd!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문예정일을 선택해 주세요.')));
      return;
    }
    if (_outcome == SupportConsultOutcome.visit &&
        (_visitTeamId == null || _visitTeamId!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문 팀을 선택해 주세요.')));
      return;
    }
    if (_outcome == SupportConsultOutcome.visit &&
        (_visitTime == null || _visitTime!.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문 시간을 선택해 주세요.')));
      return;
    }
    if (_outcome == SupportConsultOutcome.verbalQuote &&
        (_verbalAmount == null || _verbalAmount! <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('구두 견적 금액을 입력해 주세요.')));
      return;
    }
    if (_outcome == SupportConsultOutcome.quoteSend && _quoteDoc == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('견적서를 작성해 주세요.')));
      return;
    }
    var consultText = text;
    if (_outcome == SupportConsultOutcome.quoteSend &&
        _quoteDoc != null &&
        consultText.isEmpty) {
      consultText = supportQuoteConsultBody(_quoteDoc!);
    }
    if (_outcome == SupportConsultOutcome.visit && consultText.isEmpty) {
      consultText = supportVisitConsultBody(
        ymd: _visitYmd!,
        time: _visitTime!,
        teamLabel: _visitTeamLabel,
      );
    }
    if (consultText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상담 내용을 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(authControllerProvider);
      await ref
          .read(supportCallLogRepositoryProvider)
          .addConsultation(
            callLogId: widget.log.id,
            description: consultText,
            createdBy: user?.name ?? user?.id,
            currentStatusId: widget.log.serviceStatusId,
            outcome: _outcome,
            visitYmd: _visitYmd,
            visitTeamId: _visitTeamId,
            visitTime: _visitTime,
            visitTeamLabel: _visitTeamLabel,
            sendYmd: _sendYmd,
            amount: _outcome == SupportConsultOutcome.verbalQuote
                ? _verbalAmount
                : _outcome == SupportConsultOutcome.quoteSend
                ? _quoteDoc?.total
                : null,
          );
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
    final media = MediaQuery.of(context);
    // 키보드는 시트 전체를 올리고, Android 네비는 하단 버튼 SafeArea로만 처리.
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
                    Text(
                      '${widget.stage}차 상담내용',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.stage == 1
                          ? '${widget.log.customerName} · 마무리 / 피드백 대기 / 구두 견적 / 정식 견적서 / 방문'
                          : widget.lastOutcome ==
                                SupportConsultOutcome.feedbackWait
                          ? '${widget.log.customerName} · 다시 연락 왔으면 마무리하거나 방문·견적을 잡습니다'
                          : widget.lastOutcome ==
                                SupportConsultOutcome.verbalQuote
                          ? '${widget.log.customerName} · 다시 전화 왔으면 방문일을 잡고, 그날 방문합니다'
                          : '${widget.log.customerName} · 답이 왔으면 마무리·정식 견적서·방문을 고릅니다',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (_outcome != SupportConsultOutcome.verbalQuote) ...[
                      const SizedBox(height: 12),
                      SupportUnitPriceOpenTile(
                        subtitle: '상담 중 품명 · 금액 검색. 고르면 상담 내용에 넣습니다',
                        insertLabel: '상담에 넣기',
                        onInsert: (item) {
                          final line = supportUnitPriceInsertLine(item);
                          final cur = _ctrl.text.trim();
                          _ctrl.text = cur.isEmpty ? line : '$cur\n$line';
                          _ctrl.selection = TextSelection.collapsed(
                            offset: _ctrl.text.length,
                          );
                          setState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '상담 결과',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _OutcomeChip(
                                outcome: SupportConsultOutcome.closed,
                                selected:
                                    _outcome == SupportConsultOutcome.closed,
                                enabled: !_saving,
                                onTap: () => setState(
                                  () =>
                                      _outcome = SupportConsultOutcome.closed,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _OutcomeChip(
                                outcome: SupportConsultOutcome.feedbackWait,
                                selected:
                                    _outcome ==
                                    SupportConsultOutcome.feedbackWait,
                                enabled: !_saving,
                                onTap: () => setState(
                                  () => _outcome =
                                      SupportConsultOutcome.feedbackWait,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _OutcomeChip(
                                outcome: SupportConsultOutcome.verbalQuote,
                                selected:
                                    _outcome ==
                                    SupportConsultOutcome.verbalQuote,
                                enabled: !_saving,
                                onTap: () => setState(
                                  () => _outcome =
                                      SupportConsultOutcome.verbalQuote,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _OutcomeChip(
                                outcome: SupportConsultOutcome.quoteSend,
                                selected:
                                    _outcome ==
                                    SupportConsultOutcome.quoteSend,
                                enabled: !_saving,
                                onTap: () => setState(
                                  () => _outcome =
                                      SupportConsultOutcome.quoteSend,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _OutcomeChip(
                          outcome: SupportConsultOutcome.visit,
                          selected: _outcome == SupportConsultOutcome.visit,
                          enabled: !_saving,
                          onTap: () {
                            setState(
                              () => _outcome = SupportConsultOutcome.visit,
                            );
                            if (_visitYmd == null) {
                              unawaited(_pickDate(visit: true));
                            }
                          },
                        ),
                      ],
                    ),
                    if (_outcome != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        supportConsultOutcomeHint(_outcome!),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                    if (_outcome == SupportConsultOutcome.verbalQuote) ...[
                      const SizedBox(height: 12),
                      _VerbalQuoteFields(
                        amountCtrl: _amountCtrl,
                        contentCtrl: _ctrl,
                        enabled: !_saving,
                      ),
                    ],
                    if (_outcome == SupportConsultOutcome.quoteSend) ...[
                      const SizedBox(height: 10),
                      _QuotePriceCheckTile(
                        enabled: !_saving,
                        written: _quoteDoc != null,
                        summary: _quoteDoc == null
                            ? null
                            : supportQuoteHistoryLine(_quoteDoc!),
                        onTap: _openQuoteWriter,
                      ),
                      if (_quoteDoc != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _openQuoteExport,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('이미지 · PDF · 이메일'),
                        ),
                      ],
                    ],
                    if (_outcome == SupportConsultOutcome.quoteSend) ...[
                      const SizedBox(height: 10),
                      _DateActionTile(
                        icon: Icons.send_outlined,
                        title: '언제까지 보낼지',
                        value:
                            '${_ymdLabel(_sendYmd)}${_sendYmd == todayYmdSeoul() ? ' · 오늘' : ''}',
                        filled: true,
                        onTap: _saving
                            ? null
                            : () => _pickDate(visit: false),
                      ),
                    ],
                    if (_outcome == SupportConsultOutcome.visit) ...[
                      const SizedBox(height: 10),
                      _DateActionTile(
                        icon: Icons.event_available_rounded,
                        title: '방문예정일',
                        value: _visitYmd == null
                            ? '방문일을 잡고, 다녀온 뒤 방문 기록을 남깁니다'
                            : [
                                _ymdLabel(_visitYmd!),
                                if ((_visitTime ?? '').isNotEmpty)
                                  _visitTime!,
                                if ((_visitTeamLabel ?? '').isNotEmpty)
                                  _visitTeamLabel!,
                              ].join(' · '),
                        filled: _visitYmd != null,
                        onTap: _saving
                            ? null
                            : () => _pickDate(visit: true),
                      ),
                    ],
                    if (_outcome != SupportConsultOutcome.verbalQuote) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ctrl,
                        minLines: 3,
                        maxLines: 6,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          hintText: switch (_outcome) {
                            SupportConsultOutcome.feedbackWait =>
                              '전화로 안내·조치한 내용을 적어 주세요',
                            SupportConsultOutcome.visit =>
                              '상담 내용(선택) · 비워도 방문일정·시간으로 저장됩니다',
                            _ => '상담 내용을 입력해 주세요',
                          },
                          filled: true,
                        ),
                      ),
                    ],
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
                        child: const Text('나중에'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _saving
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                _save();
                              },
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(switch (_outcome) {
                                SupportConsultOutcome.closed => '마무리 저장',
                                SupportConsultOutcome.feedbackWait =>
                                  '피드백 대기로 저장',
                                SupportConsultOutcome.verbalQuote =>
                                  '구두 견적 저장',
                                SupportConsultOutcome.quoteSend => '견적 저장',
                                SupportConsultOutcome.visit => '방문일 저장',
                                null => '저장',
                              }),
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

class _VerbalQuoteFields extends StatelessWidget {
  const _VerbalQuoteFields({
    required this.amountCtrl,
    required this.contentCtrl,
    required this.enabled,
  });

  final TextEditingController amountCtrl;
  final TextEditingController contentCtrl;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerbalQuoteBox(
          title: '전달 금액',
          icon: Icons.payments_outlined,
          color: const Color(0xFFD97706),
          child: TextField(
            controller: amountCtrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: const [_WonThousandsFormatter()],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              hintText: '여기를 눌러 금액 입력',
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.38),
              ),
              suffixText: '원',
              suffixStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              filled: true,
              fillColor: scheme.surface,
              contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _VerbalQuoteBox(
          title: '전달 내용',
          icon: Icons.notes_rounded,
          color: AppTokens.info(scheme),
          child: TextField(
            controller: contentCtrl,
            enabled: enabled,
            minLines: 5,
            maxLines: 8,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: '여기를 눌러 구두로 안내한 내용을 입력',
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.38),
              ),
              filled: true,
              fillColor: scheme.surface,
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _WonThousandsFormatter extends TextInputFormatter {
  const _WonThousandsFormatter();

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

class _VerbalQuoteBox extends StatelessWidget {
  const _VerbalQuoteBox({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({
    required this.outcome,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final SupportConsultOutcome outcome;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (outcome) {
      SupportConsultOutcome.closed => AppTokens.success(scheme),
      SupportConsultOutcome.feedbackWait => const Color(0xFFD97706),
      SupportConsultOutcome.verbalQuote => AppTokens.info(scheme),
      SupportConsultOutcome.quoteSend => scheme.primary,
      SupportConsultOutcome.visit => AppTokens.customerSupportAccent(scheme),
    };
    final icon = switch (outcome) {
      SupportConsultOutcome.closed => Icons.task_alt_rounded,
      SupportConsultOutcome.feedbackWait => Icons.phonelink_ring_rounded,
      SupportConsultOutcome.verbalQuote => Icons.forum_outlined,
      SupportConsultOutcome.quoteSend => Icons.send_outlined,
      SupportConsultOutcome.visit => Icons.event_available_rounded,
    };
    final fg = selected ? Colors.white : scheme.onSurface;
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    supportConsultOutcomeLabel(outcome),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateActionTile extends StatelessWidget {
  const _DateActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.filled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Material(
      color: filled
          ? accent.withValues(alpha: 0.14)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.event_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotePriceCheckTile extends StatelessWidget {
  const _QuotePriceCheckTile({
    required this.enabled,
    required this.onTap,
    this.written = false,
    this.summary,
  });

  final bool enabled;
  final VoidCallback onTap;
  final bool written;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.request_quote_outlined, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      written ? '견적서 수정' : '견적서 작성',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      summary ?? '작성하면 이 상담 내용에 저장되고 이미지·PDF·이메일로 보낼 수 있습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
