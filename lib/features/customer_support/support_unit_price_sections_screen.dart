import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 큰분류(SPD/WMS/OHD)·작은분류(CONTROLLER 전자제어장치 등) 추가·수정·삭제.
class SupportUnitPriceSectionsScreen extends ConsumerStatefulWidget {
  const SupportUnitPriceSectionsScreen({
    super.key,
    required this.items,
    required this.sections,
  });

  final List<SupportUnitPriceItem> items;
  final List<SupportUnitPriceSection> sections;

  @override
  ConsumerState<SupportUnitPriceSectionsScreen> createState() =>
      _SupportUnitPriceSectionsScreenState();
}

class _SupportUnitPriceSectionsScreenState
    extends ConsumerState<SupportUnitPriceSectionsScreen> {
  late List<SupportUnitPriceItem> _items;
  late List<SupportUnitPriceSection> _sections;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = widget.items;
    _sections = widget.sections;
  }

  (String, String) _actor() {
    final user = ref.read(authControllerProvider);
    return (user?.id ?? '', (user?.name ?? '').trim());
  }

  Future<void> _reload() async {
    final repo = ref.read(supportUnitPriceRepositoryProvider);
    final items = await repo.list();
    final sections = await repo.listSections();
    if (!mounted) return;
    setState(() {
      _items = items;
      _sections = sections;
    });
  }

  List<String> get _lines => supportUnitPriceDistinctLines(
    items: _items,
    sections: _sections,
  );

  List<String> _cats(String line) => supportUnitPriceDistinctCategories(
    items: _items,
    sections: _sections,
    productLine: line,
  );

  int _lineCount(String line) =>
      _items.where((e) => e.productLine.trim() == line).length;

  int _catCount(String line, String cat) => _items
      .where(
        (e) => e.productLine.trim() == line && e.category.trim() == cat,
      )
      .length;

  Future<String?> _askName({
    required String title,
    required String label,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label, filled: true),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return value;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLine() async {
    final name = await _askName(title: '큰분류 추가', label: '큰분류 (예: SPD)');
    if (name == null || name.isEmpty) return;
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .addSection(productLine: name, category: ''),
    );
  }

  Future<void> _addCategory(String line) async {
    final name = await _askName(
      title: '작은분류 추가',
      label: '작은분류 (예: CONTROLLER 전자제어장치)',
    );
    if (name == null || name.isEmpty) return;
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .addSection(productLine: line, category: name),
    );
  }

  Future<void> _renameLine(String line) async {
    final name = await _askName(
      title: '큰분류 수정',
      label: '큰분류',
      initial: line,
    );
    if (name == null || name.isEmpty || name == line) return;
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .renameProductLine(from: line, to: name),
    );
  }

  Future<void> _renameCategory(String line, String cat) async {
    final name = await _askName(
      title: '작은분류 수정',
      label: '작은분류',
      initial: cat,
    );
    if (name == null || name.isEmpty || name == cat) return;
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .renameCategory(productLine: line, from: cat, to: name),
    );
  }

  Future<void> _deleteLine(String line) async {
    final count = _lineCount(line);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('큰분류 삭제'),
        content: Text(
          count == 0
              ? '$line 분류를 삭제할까요?'
              : '$line 분류와 단가 $count건을 삭제할까요?\n삭제해도 변경 이력은 남습니다.',
        ),
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
    final actor = _actor();
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .deleteProductLine(
            productLine: line,
            userId: actor.$1,
            userName: actor.$2.isEmpty ? '알 수 없음' : actor.$2,
          ),
    );
  }

  Future<void> _deleteCategory(String line, String cat) async {
    final count = _catCount(line, cat);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작은분류 삭제'),
        content: Text(
          count == 0
              ? '$cat 분류를 삭제할까요?'
              : '$cat 분류와 단가 $count건을 삭제할까요?\n삭제해도 변경 이력은 남습니다.',
        ),
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
    final actor = _actor();
    await _run(
      () => ref
          .read(supportUnitPriceRepositoryProvider)
          .deleteCategory(
            productLine: line,
            category: cat,
            userId: actor.$1,
            userName: actor.$2.isEmpty ? '알 수 없음' : actor.$2,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final lines = _lines;
    return Scaffold(
      appBar: AppBar(title: const Text('분류 관리')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addLine,
        icon: const Icon(Icons.add_rounded),
        label: const Text('큰분류 추가'),
      ),
      body: lines.isEmpty
          ? AppEmpty(
              icon: Icons.account_tree_outlined,
              message: '큰분류가 없습니다.',
              detail: 'SPD, WMS, OHD처럼 큰분류를 먼저 추가해 주세요.',
              actionLabel: '큰분류 추가',
              onAction: _addLine,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: lines.length,
              itemBuilder: (context, i) {
                final line = lines[i];
                final cats = _cats(line);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                  ),
                                ),
                              ),
                              Text(
                                '${_lineCount(line)}건',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              IconButton(
                                tooltip: '큰분류 수정',
                                onPressed: _busy
                                    ? null
                                    : () => _renameLine(line),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                              IconButton(
                                tooltip: '큰분류 삭제',
                                onPressed: _busy
                                    ? null
                                    : () => _deleteLine(line),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          for (final cat in cats)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_catCount(line, cat)}건',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '작은분류 수정',
                                    onPressed: _busy
                                        ? null
                                        : () => _renameCategory(line, cat),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '작은분류 삭제',
                                    onPressed: _busy
                                        ? null
                                        : () => _deleteCategory(line, cat),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _addCategory(line),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('작은분류 추가'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
