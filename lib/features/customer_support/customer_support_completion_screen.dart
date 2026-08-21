import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/widgets/form_section.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerSupportCompletionScreen extends ConsumerStatefulWidget {
  const CustomerSupportCompletionScreen({super.key, this.site});

  final SupportSiteSample? site;

  @override
  ConsumerState<CustomerSupportCompletionScreen> createState() =>
      _CustomerSupportCompletionScreenState();
}

class _CustomerSupportCompletionScreenState
    extends ConsumerState<CustomerSupportCompletionScreen> {
  final _amountCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  DateTime? _due;
  final List<String> _materials = [];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _materialCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.parse(todayYmdSeoul());
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => _due = picked);
  }

  void _addMaterial() {
    final v = _materialCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _materials.add(v);
      _materialCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final site = widget.site;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('완료확인서')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                const SupportComingSoonBanner(
                  message: '사인 받거나 양식을 넣는 자리입니다. 저장·PDF는 다음 작업입니다.',
                ),
                const SizedBox(height: 16),
                const FormSectionHeader(
                  title: '현장 · 담당자',
                  icon: Icons.home_work_outlined,
                  step: 1,
                ),
                const SizedBox(height: 8),
                Text(site?.name ?? '현장을 선택하지 않았습니다'),
                Text(
                  site?.address ?? '현장검색에서 들어와 주세요',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text('담당자: ${user?.name ?? '-'}'),
                const SizedBox(height: 20),
                const FormSectionHeader(
                  title: '금액 · 입금예정일',
                  icon: Icons.payments_outlined,
                  step: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '금액',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('입금예정일'),
                  subtitle: Text(
                    _due == null ? '날짜 선택' : ymdSeoulFromDateTime(_due!),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDue,
                ),
                const SizedBox(height: 12),
                const FormSectionHeader(
                  title: '사인',
                  icon: Icons.draw_outlined,
                  step: 3,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => showSupportSkeletonSnack(context, '사인 패드'),
                  child: Container(
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      '여기를 눌러 사인',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const FormSectionHeader(
                  title: '투입 자재',
                  icon: Icons.inventory_2_outlined,
                  step: 4,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _materialCtrl,
                        decoration: const InputDecoration(hintText: '자재명 · 수량'),
                        onSubmitted: (_) => _addMaterial(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _addMaterial,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                if (_materials.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in _materials)
                        InputChip(
                          label: Text(m),
                          onDeleted: () => setState(() => _materials.remove(m)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          UxActionDock(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerSupportCollectionScreen(),
                  ),
                ),
                child: const Text('수금'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportIssuancePage(),
                  ),
                ),
                child: const Text('다음 · 세금계산서'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
