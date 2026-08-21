import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A/S 견적단가표. 사이즈 표준단가와 별개이며, 현장에서 직접 입력·검색한다.
class SupportUnitPriceScreen extends ConsumerStatefulWidget {
  const SupportUnitPriceScreen({super.key});

  @override
  ConsumerState<SupportUnitPriceScreen> createState() =>
      _SupportUnitPriceScreenState();
}

class _SupportUnitPriceScreenState
    extends ConsumerState<SupportUnitPriceScreen> {
  final _queryCtrl = TextEditingController();
  late SupportUnitPriceStore _store;
  List<SupportUnitPriceItem> _items = const [];
  String _query = '';
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _store = SupportUnitPriceStore(ref.read(appDependenciesProvider).prefs);
    _items = _store.load();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportUnitPriceItem> get _visible {
    return _items.where((e) => supportUnitPriceMatches(e, _query)).toList();
  }

  Future<void> _persist(List<SupportUnitPriceItem> next) async {
    setState(() => _items = next);
    await _store.save(next);
  }

  Future<void> _edit({SupportUnitPriceItem? existing}) async {
    final saved = await showModalBottomSheet<SupportUnitPriceItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SupportUnitPriceEditor(existing: existing),
    );
    if (saved == null || !mounted) return;
    final next = [..._items];
    final i = next.indexWhere((e) => e.id == saved.id);
    if (i >= 0) {
      next[i] = saved;
    } else {
      next.insert(0, saved);
    }
    await _persist(next);
  }

  Future<void> _delete(SupportUnitPriceItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단가 삭제'),
        content: Text('${item.name}을(를) 삭제할까요?'),
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
    if (ok != true || !mounted) return;
    await _persist(_items.where((e) => e.id != item.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/S 견적단가'),
        actions: [
          IconButton(
            tooltip: '단가 추가',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('단가 입력'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '품명 · 규격 · 비고 검색',
              leading: const Icon(Icons.search_rounded, size: 20),
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? AppEmpty(
                    icon: Icons.grid_on_outlined,
                    message: _query.trim().isEmpty
                        ? '아직 입력된 A/S 단가가 없습니다.'
                        : '검색 결과가 없습니다.',
                    detail: _query.trim().isEmpty
                        ? '표준단가와 별개입니다. 현장에서 쓰는 단가를 입력해 주세요.'
                        : null,
                    actionLabel: _query.trim().isEmpty ? '단가 입력' : null,
                    onAction: _query.trim().isEmpty ? () => _edit() : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = rows[i];
                      return Material(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.42,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              if (item.spec.trim().isNotEmpty) item.spec.trim(),
                              if (item.note.trim().isNotEmpty) item.note.trim(),
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            item.price == null
                                ? '-'
                                : '${_won.format(item.price)}원',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          onTap: () => _edit(existing: item),
                          onLongPress: () => _delete(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportUnitPriceEditor extends StatefulWidget {
  const _SupportUnitPriceEditor({this.existing});

  final SupportUnitPriceItem? existing;

  @override
  State<_SupportUnitPriceEditor> createState() =>
      _SupportUnitPriceEditorState();
}

class _SupportUnitPriceEditorState extends State<_SupportUnitPriceEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _specCtrl = TextEditingController(text: e?.spec ?? '');
    _priceCtrl = TextEditingController(
      text: e?.price == null ? '' : '${e!.price}',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품명을 입력해 주세요.')));
      return;
    }
    final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
    Navigator.of(context).pop(
      SupportUnitPriceItem(
        id:
            widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        spec: _specCtrl.text.trim(),
        price: (price ?? 0) > 0 ? price : null,
        note: _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? '단가 입력' : '단가 수정',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '품명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '규격',
              hintText: '선택',
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '단가',
              hintText: '숫자만',
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: '비고', filled: true),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: const Text('저장')),
          ),
        ],
      ),
    );
  }
}
