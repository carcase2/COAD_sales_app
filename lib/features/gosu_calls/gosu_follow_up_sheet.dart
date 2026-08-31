import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<GosuSalesCall?> showGosuFollowUpSheet({
  required BuildContext context,
  required WidgetRef ref,
  required GosuSalesCall row,
}) {
  return showModalBottomSheet<GosuSalesCall>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _GosuFollowUpSheet(row: row),
  );
}

class _GosuFollowUpSheet extends ConsumerStatefulWidget {
  const _GosuFollowUpSheet({required this.row});

  final GosuSalesCall row;

  @override
  ConsumerState<_GosuFollowUpSheet> createState() => _GosuFollowUpSheetState();
}

class _GosuFollowUpSheetState extends ConsumerState<_GosuFollowUpSheet> {
  final _contentCtrl = TextEditingController();
  String _followResult = kGosuProgressOpen;
  String? _nextDate;
  bool _saving = false;
  String? _error;
  GosuSalesCall? _resolved;

  GosuSalesCall get _row => _resolved ?? widget.row;

  @override
  void initState() {
    super.initState();
    _nextDate = widget.row.followCalendarDateKey.isEmpty
        ? null
        : widget.row.followCalendarDateKey;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detailed = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchById(widget.row.id);
      if (!mounted) return;
      setState(() {
        _resolved = detailed;
        if ((detailed.nextScheduledDate ?? '').trim().isNotEmpty) {
          _nextDate = detailed.followCalendarDateKey;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  int get _nextStage =>
      getNextGosuFollowUpStage(_row.callHistory.length, _row.callStage);

  Future<void> _pickDate() async {
    final today = DateTime.tryParse(todayYmdSeoul()) ?? DateTime.now();
    final initial = DateTime.tryParse(_nextDate ?? todayYmdSeoul()) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _nextDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(authControllerProvider);
      final saved = await ref.read(gosuSalesCallsRepositoryProvider).saveFollowUp(
            callId: _row.id,
            consultationContent: _contentCtrl.text,
            followResult: _followResult,
            nextScheduledDate: _nextDate,
            createdBy: user?.name ?? '시스템',
          );
      invalidateHomeSalesCaches(ref.invalidate);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = koreanErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final history = _row.callHistory;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${gosuStageLabel(_nextStage)} 입력',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${_row.displayName} · ${_row.displayPhone}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '문의 내용',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: accent,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _row.inquiryContent?.trim().isNotEmpty == true
                        ? _row.inquiryContent!.trim()
                        : '문의 내용 없음',
                  ),
                ],
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '이전 팔로업 (${history.length}회)',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final h in history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              gosuStageLabel(h.callStage),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              h.followResult,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: h.followResult == kGosuProgressClosed
                                    ? scheme.onSurfaceVariant
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(h.consultationContent),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: '${gosuStageLabel(_nextStage)} 내용 *',
                hintText: '통화·처리 내용을 입력하세요.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '처리 결과',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ResultChip(
                    label: '진행중',
                    selected: _followResult == kGosuProgressOpen,
                    color: const Color(0xFFF59E0B),
                    onTap: () =>
                        setState(() => _followResult = kGosuProgressOpen),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultChip(
                    label: '종료',
                    selected: _followResult == kGosuProgressClosed,
                    color: const Color(0xFF334155),
                    onTap: () =>
                        setState(() => _followResult = kGosuProgressClosed),
                  ),
                ),
              ],
            ),
            if (_followResult == kGosuProgressOpen) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '다음 팔로업 예정일 *',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(_nextDate ?? '날짜를 선택하세요'),
                trailing: const Icon(Icons.event_rounded),
                onTap: _pickDate,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(AppTokens.primaryCtaHeight),
              ),
              child: Text(_saving ? '저장 중…' : '$_nextStage차 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
