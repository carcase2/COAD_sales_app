import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_quote_screen.dart';
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
    useSafeArea: true,
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
  bool _saving = false;
  SupportConsultOutcome? _outcome;
  late String _sendYmd;
  String? _visitYmd;

  @override
  void initState() {
    super.initState();
    _sendYmd = todayYmdSeoul();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _ymdLabel(String ymd) {
    if (ymd.length < 10) return ymd;
    final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
    final d = int.tryParse(ymd.substring(8, 10)) ?? 0;
    return '$m/$d';
  }

  Future<void> _pickDate({required bool visit}) async {
    if (visit) {
      final ymd = await showSupportVisitDatePicker(
        context,
        log: widget.log,
        selectedYmd: _visitYmd,
      );
      if (ymd == null || !mounted) return;
      setState(() => _visitYmd = ymd);
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

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상담 내용을 입력해 주세요.')));
      return;
    }
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
    setState(() => _saving = true);
    try {
      final user = ref.read(authControllerProvider);
      await ref
          .read(supportCallLogRepositoryProvider)
          .addConsultation(
            callLogId: widget.log.id,
            description: text,
            createdBy: user?.name ?? user?.id,
            currentStatusId: widget.log.serviceStatusId,
            outcome: _outcome,
            visitYmd: _visitYmd,
            sendYmd: _sendYmd,
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
    final bottom = media.viewInsets.bottom + media.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.stage}차 상담내용',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              widget.stage == 1
                  ? '${widget.log.customerName} · 마무리 / 피드백 대기 / 구두 견적 / 정식 견적서 / 방문'
                  : widget.lastOutcome == SupportConsultOutcome.feedbackWait
                  ? '${widget.log.customerName} · 다시 연락 왔으면 마무리하거나 방문·견적을 잡습니다'
                  : widget.lastOutcome == SupportConsultOutcome.verbalQuote
                  ? '${widget.log.customerName} · 다시 전화 왔으면 방문일을 잡고, 그날 방문합니다'
                  : '${widget.log.customerName} · 답이 왔으면 마무리·정식 견적서·방문을 고릅니다',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
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
                        selected: _outcome == SupportConsultOutcome.closed,
                        enabled: !_saving,
                        onTap: () => setState(
                          () => _outcome = SupportConsultOutcome.closed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OutcomeChip(
                        outcome: SupportConsultOutcome.feedbackWait,
                        selected:
                            _outcome == SupportConsultOutcome.feedbackWait,
                        enabled: !_saving,
                        onTap: () => setState(
                          () => _outcome = SupportConsultOutcome.feedbackWait,
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
                        selected: _outcome == SupportConsultOutcome.verbalQuote,
                        enabled: !_saving,
                        onTap: () => setState(
                          () => _outcome = SupportConsultOutcome.verbalQuote,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OutcomeChip(
                        outcome: SupportConsultOutcome.quoteSend,
                        selected: _outcome == SupportConsultOutcome.quoteSend,
                        enabled: !_saving,
                        onTap: () => setState(
                          () => _outcome = SupportConsultOutcome.quoteSend,
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
                    setState(() => _outcome = SupportConsultOutcome.visit);
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
            if (_outcome == SupportConsultOutcome.verbalQuote ||
                _outcome == SupportConsultOutcome.quoteSend) ...[
              const SizedBox(height: 10),
              _QuotePriceCheckTile(
                enabled: !_saving,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerSupportQuoteScreen(),
                    ),
                  );
                },
              ),
            ],
            if (_outcome == SupportConsultOutcome.quoteSend) ...[
              const SizedBox(height: 10),
              _DateActionTile(
                icon: Icons.send_outlined,
                title: '언제까지 보낼지',
                value:
                    '${_ymdLabel(_sendYmd)}${_sendYmd == todayYmdSeoul() ? ' · 오늘' : ''}',
                filled: true,
                onTap: _saving ? null : () => _pickDate(visit: false),
              ),
            ],
            if (_outcome == SupportConsultOutcome.visit) ...[
              const SizedBox(height: 10),
              _DateActionTile(
                icon: Icons.event_available_rounded,
                title: '방문예정일',
                value: _visitYmd == null
                    ? '방문일을 잡고, 다녀온 뒤 방문 기록을 남깁니다'
                    : _ymdLabel(_visitYmd!),
                filled: _visitYmd != null,
                onTap: _saving ? null : () => _pickDate(visit: true),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              minLines: 3,
              maxLines: 6,
              enabled: !_saving,
              decoration: InputDecoration(
                hintText: _outcome == SupportConsultOutcome.feedbackWait
                    ? '전화로 안내·조치한 내용을 적어 주세요'
                    : '상담 내용을 입력해 주세요',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(switch (_outcome) {
                          SupportConsultOutcome.closed => '마무리 저장',
                          SupportConsultOutcome.feedbackWait => '피드백 대기로 저장',
                          SupportConsultOutcome.verbalQuote => '답 대기로 저장',
                          SupportConsultOutcome.quoteSend => '발송일 저장',
                          SupportConsultOutcome.visit => '방문일 저장',
                          null => '저장',
                        }),
                ),
              ],
            ),
          ],
        ),
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
  const _QuotePriceCheckTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

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
                      '견적서 작성',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '단가 확인 · 정식 견적서 작성 · 이미지/PDF 발송',
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
