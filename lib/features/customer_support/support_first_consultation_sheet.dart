import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_quote_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
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
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SupportFirstConsultationSheet(log: log, stage: stage),
  );
  return saved == true;
}

class _SupportFirstConsultationSheet extends ConsumerStatefulWidget {
  const _SupportFirstConsultationSheet({
    required this.log,
    required this.stage,
  });

  final SupportCallLog log;
  final int stage;

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
    final initial =
        DateTime.tryParse(visit ? (_visitYmd ?? _sendYmd) : _sendYmd) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final ymd =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (visit) {
        _visitYmd = ymd;
      } else {
        _sendYmd = ymd;
      }
    });
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
              '${widget.log.customerName} · 결과를 고르면 미처리에서 빠집니다',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in SupportConsultOutcome.values)
                  ChoiceChip(
                    label: Text(supportConsultOutcomeLabel(item)),
                    selected: _outcome == item,
                    onSelected: _saving
                        ? null
                        : (_) => setState(() => _outcome = item),
                  ),
              ],
            ),
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
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.send_outlined),
                title: const Text('발송예정일'),
                subtitle: Text(
                  '${_ymdLabel(_sendYmd)}${_sendYmd == todayYmdSeoul() ? ' · 오늘' : ''}',
                ),
                trailing: const Icon(Icons.event_rounded),
                onTap: _saving ? null : () => _pickDate(visit: false),
              ),
            ],
            if (_outcome == SupportConsultOutcome.visit) ...[
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_rounded),
                title: const Text('방문예정일'),
                subtitle: Text(
                  _visitYmd == null ? '날짜를 선택해 주세요' : _ymdLabel(_visitYmd!),
                ),
                trailing: const Icon(Icons.event_rounded),
                onTap: _saving ? null : () => _pickDate(visit: true),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              minLines: 3,
              maxLines: 6,
              enabled: !_saving,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '상담 내용을 입력해 주세요',
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
                      '견적단가 확인',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '단가표·견적기를 열어 확인하고 상담에 반영합니다',
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
