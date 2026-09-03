import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_choice_chip.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_follow_up_sheet.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GosuCallDetailScreen extends ConsumerStatefulWidget {
  const GosuCallDetailScreen({super.key, required this.id, this.initial});

  final String id;
  final GosuSalesCall? initial;

  @override
  ConsumerState<GosuCallDetailScreen> createState() =>
      _GosuCallDetailScreenState();
}

class _GosuCallDetailScreenState extends ConsumerState<GosuCallDetailScreen> {
  GosuSalesCall? _row;
  bool _loading = true;
  bool _saving = false;
  Object? _error;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _inquiryCtrl;
  String? _categoryName;
  String? _methodName;
  String _inquiryKind = kGosuInquiryKindDefault;
  String _assignedTo = '';
  List<String> _assignees = [];

  List<String> get _assigneeChoices => gosuAssigneeChoices(
    departmentNames: _assignees,
    assignedTo: _assignedTo,
  );

  @override
  void initState() {
    super.initState();
    _row = widget.initial;
    _nameCtrl = TextEditingController(text: widget.initial?.customerName ?? '');
    _phoneCtrl = TextEditingController(
      text: widget.initial?.customerPhone ?? '',
    );
    _inquiryCtrl = TextEditingController(
      text: widget.initial?.inquiryContent ?? '',
    );
    _categoryName = widget.initial?.productCategoryName;
    _methodName = widget.initial?.inquiryMethodName;
    _inquiryKind = normalizeGosuInquiryKind(widget.initial?.inquiryKind);
    _assignedTo = widget.initial?.assignedTo ?? '';
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _row == null;
      _error = null;
    });
    try {
      final detailed = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchById(widget.id);
      final names = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchAssignees();
      if (!mounted) return;
      setState(() {
        _row = detailed;
        _nameCtrl.text = detailed.customerName ?? '';
        _phoneCtrl.text = detailed.customerPhone ?? '';
        _inquiryCtrl.text = detailed.inquiryContent ?? '';
        _categoryName = detailed.productCategoryName;
        _methodName = detailed.inquiryMethodName;
        _inquiryKind = normalizeGosuInquiryKind(detailed.inquiryKind);
        _assignedTo = detailed.assignedTo ?? '';
        _assignees = names;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _dirty {
    final row = _row;
    if (row == null) return false;
    return _nameCtrl.text.trim() != (row.customerName ?? '').trim() ||
        _phoneCtrl.text.trim() != (row.customerPhone ?? '').trim() ||
        _inquiryCtrl.text.trim() != (row.inquiryContent ?? '').trim() ||
        (_categoryName ?? '') != (row.productCategoryName ?? '') ||
        (_methodName ?? '') != (row.inquiryMethodName ?? '') ||
        _inquiryKind != normalizeGosuInquiryKind(row.inquiryKind) ||
        formatGosuAssignees(parseGosuAssignees(_assignedTo)) !=
            formatGosuAssignees(parseGosuAssignees(row.assignedTo));
  }

  Future<void> _saveBase() async {
    final row = _row;
    if (row == null || !_dirty) return;
    final assigneeError = validateGosuAssignees(_assignedTo);
    if (assigneeError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(assigneeError)));
      return;
    }
    setState(() => _saving = true);
    try {
      GosuNamedOption? method;
      for (final m in kGosuInquiryMethods) {
        if (m.name == _methodName) {
          method = m;
          break;
        }
      }
      final updated = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .updateCall(row.id, {
            'customer_name': _nameCtrl.text.trim().isEmpty
                ? '상호없음'
                : _nameCtrl.text.trim(),
            'customer_phone': _phoneCtrl.text.trim(),
            'inquiry_content': _inquiryCtrl.text,
            'product_category_name': _categoryName,
            'product_category_id': null,
            'inquiry_method_name': _methodName,
            'inquiry_method_id': method == null
                ? null
                : gosuInquiryMethodIdForStorage(method.id),
            'inquiry_kind': normalizeGosuInquiryKind(_inquiryKind),
            'assigned_to': formatGosuAssignees(
              parseGosuAssignees(_assignedTo),
            ),
            'follow_up': row.followUp ?? kGosuProgressOpen,
            'follow_up_content': row.followUpContent,
          });
      if (!mounted) return;
      setState(() {
        _row = updated;
        _inquiryKind = normalizeGosuInquiryKind(updated.inquiryKind);
        _assignedTo = updated.assignedTo ?? '';
      });
      invalidateHomeSalesCaches(ref.invalidate);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기본 정보가 저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _followUp() async {
    final row = _row;
    if (row == null) return;
    final saved = await showGosuFollowUpSheet(
      context: context,
      ref: ref,
      row: row,
    );
    if (saved != null && mounted) {
      setState(() => _row = saved);
      invalidateHomeSalesCaches(ref.invalidate);
    }
  }

  Future<void> _delete() async {
    final row = _row;
    if (row == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('접수 삭제'),
        content: const Text('이 자동문의고수 접수를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gosuSalesCallsRepositoryProvider).deleteCall(row.id);
      invalidateHomeSalesCaches(ref.invalidate);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final row = _row;
    return Scaffold(
      appBar: AppBar(
        title: const Text('자동문의고수 상세'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '삭제',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: '상세를 불러오는 중…')
          : _error != null && row == null
          ? AppErrorState(message: koreanErrorMessage(_error!), onRetry: _load)
          : row == null
          ? const AppEmpty(message: '접수를 찾을 수 없습니다.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(gosuWorkflowStatusLabel(row)),
                      backgroundColor: accent.withValues(alpha: 0.14),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        gosuStageLabel(row.callStage),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${row.callDate ?? ''} ${row.callTime ?? ''}'.trim(),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: '고객명/상호'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '연락처',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '전화',
                          onPressed: () =>
                              LauncherUtils.makePhoneCall(_phoneCtrl.text),
                          icon: const Icon(Icons.call_rounded),
                        ),
                        IconButton(
                          tooltip: '문자',
                          onPressed: () =>
                              LauncherUtils.sendSMS(_phoneCtrl.text),
                          icon: const Icon(Icons.sms_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  row.displayRegion,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                const Text(
                  '제품군',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in kGosuProductCategories)
                      GosuChoiceChip(
                        label: c.name,
                        selected: _categoryName == c.name,
                        selectedColor: gosuChipColorFromHex(c.colorHex),
                        onSelected: (_) =>
                            setState(() => _categoryName = c.name),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '문의종류',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in kGosuInquiryKinds)
                      GosuChoiceChip(
                        label: k.name,
                        selected: _inquiryKind == k.name,
                        selectedColor: gosuChipColorFromHex(k.colorHex),
                        onSelected: (_) =>
                            setState(() => _inquiryKind = k.name),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '문의방법',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in kGosuInquiryMethods)
                      GosuChoiceChip(
                        label: m.name,
                        selected: _methodName == m.name,
                        selectedColor: gosuChipColorFromHex(m.colorHex),
                        onSelected: (_) => setState(() => _methodName = m.name),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '담당자 *',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '여러 명 선택 가능 · 1명 이상 필수',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (_assigneeChoices.isEmpty)
                  Text(
                    '자동문의고수 부서 담당자가 없습니다',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _assigneeChoices)
                        GosuChoiceChip(
                          label: name,
                          selected: parseGosuAssignees(
                            _assignedTo,
                          ).contains(name),
                          onSelected: (_) => setState(
                            () => _assignedTo = toggleGosuAssignee(
                              _assignedTo,
                              name,
                              required: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inquiryCtrl,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: '문의 내용'),
                ),
                if (row.images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SalesCallAttachmentsStrip(urls: row.images, editable: false),
                ],
                if (_dirty) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _saveBase,
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    child: Text(_saving ? '저장 중…' : '기본 정보 저장'),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _followUp,
                  icon: const Icon(Icons.phone_callback_rounded),
                  label: Text(
                    '${gosuStageLabel(getNextGosuFollowUpStage(row.callHistory.length, row.callStage))} 입력',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(
                      AppTokens.primaryCtaHeight,
                    ),
                  ),
                ),
                if (row.callHistory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '팔로업 이력',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  for (final h in row.callHistory)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
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
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    h.followResult,
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          h.followResult == kGosuProgressClosed
                                          ? scheme.onSurfaceVariant
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${h.callDate} ${h.callTime}'.trim(),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(h.consultationContent),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
