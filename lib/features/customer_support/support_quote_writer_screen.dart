import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 고객지원팀 전용 견적서. 영업 셔터 견적서 작성과 별개.
class SupportQuoteWriterScreen extends ConsumerStatefulWidget {
  const SupportQuoteWriterScreen({super.key, this.site});

  final SupportSiteSample? site;

  @override
  ConsumerState<SupportQuoteWriterScreen> createState() =>
      _SupportQuoteWriterScreenState();
}

class _SupportQuoteWriterScreenState
    extends ConsumerState<SupportQuoteWriterScreen> {
  final _queryCtrl = TextEditingController();
  late SupportQuoteStore _store;
  List<SupportQuoteDocument> _items = const [];
  String _query = '';
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _store = SupportQuoteStore(ref.read(appDependenciesProvider).prefs);
    _items = _store.load();
    if (widget.site != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_edit());
      });
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportQuoteDocument> get _visible =>
      _items.where((e) => supportQuoteMatches(e, _query)).toList();

  Future<void> _persist(List<SupportQuoteDocument> next) async {
    setState(() => _items = next);
    await _store.save(next);
  }

  Future<void> _edit({SupportQuoteDocument? existing}) async {
    final saved = await Navigator.of(context).push<SupportQuoteDocument>(
      MaterialPageRoute(
        builder: (_) =>
            _SupportQuoteEditorPage(existing: existing, site: widget.site),
      ),
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

  Future<void> _delete(SupportQuoteDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('견적서 삭제'),
        content: Text('${doc.customerName} 견적서를 삭제할까요?'),
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
    await _persist(_items.where((e) => e.id != doc.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('A/S 견적서')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.edit_document),
        label: const Text('견적서 작성'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '고객 · 현장 · 품목 검색',
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
                    icon: Icons.request_quote_outlined,
                    message: _query.trim().isEmpty
                        ? '작성한 A/S 견적서가 없습니다.'
                        : '검색 결과가 없습니다.',
                    detail: _query.trim().isEmpty
                        ? '영업 셔터 견적서와 별개입니다. 고객지원팀 양식으로 작성합니다.'
                        : null,
                    actionLabel: _query.trim().isEmpty ? '견적서 작성' : null,
                    onAction: _query.trim().isEmpty ? () => _edit() : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = rows[i];
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
                            doc.customerName.isEmpty
                                ? '(고객 없음)'
                                : doc.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              if (doc.site.trim().isNotEmpty) doc.site.trim(),
                              doc.ymd,
                              if ((doc.createdBy ?? '').trim().isNotEmpty)
                                doc.createdBy!.trim(),
                            ].join(' · '),
                          ),
                          trailing: Text(
                            doc.total <= 0 ? '-' : '${_won.format(doc.total)}원',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          onTap: () => _edit(existing: doc),
                          onLongPress: () => _delete(doc),
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

class _SupportQuoteEditorPage extends ConsumerStatefulWidget {
  const _SupportQuoteEditorPage({this.existing, this.site});

  final SupportQuoteDocument? existing;
  final SupportSiteSample? site;

  @override
  ConsumerState<_SupportQuoteEditorPage> createState() =>
      _SupportQuoteEditorPageState();
}

class _SupportQuoteEditorPageState
    extends ConsumerState<_SupportQuoteEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  late String _ymd;
  List<SupportQuoteLine> _lines = [];
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final site = widget.site;
    _nameCtrl = TextEditingController(
      text: e?.customerName ?? site?.name ?? '',
    );
    _phoneCtrl = TextEditingController(text: e?.phone ?? site?.phone ?? '');
    _siteCtrl = TextEditingController(text: e?.site ?? site?.name ?? '');
    _addressCtrl = TextEditingController(
      text: e?.address ?? site?.address ?? '',
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _ymd = (e?.ymd ?? '').trim().isNotEmpty ? e!.ymd : todayYmdSeoul();
    _lines = List.of(e?.lines ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _siteCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _total => _lines.fold(0, (sum, e) => sum + e.amount);

  Future<void> _pickYmd() async {
    final initial = DateTime.tryParse(_ymd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      _ymd =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _addLine() async {
    final line = await showModalBottomSheet<SupportQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _SupportQuoteLineSheet(),
    );
    if (line == null || !mounted) return;
    setState(() => _lines = [..._lines, line]);
  }

  Future<void> _editLine(int index) async {
    final line = await showModalBottomSheet<SupportQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SupportQuoteLineSheet(existing: _lines[index]),
    );
    if (line == null || !mounted) return;
    setState(() {
      final next = [..._lines];
      next[index] = line;
      _lines = next;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('고객명을 입력해 주세요.')));
      return;
    }
    final user = ref.read(authControllerProvider);
    Navigator.of(context).pop(
      SupportQuoteDocument(
        id:
            widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: name,
        phone: _phoneCtrl.text.trim(),
        site: _siteCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        ymd: _ymd,
        lines: List.of(_lines),
        note: _noteCtrl.text.trim(),
        createdBy: user?.name ?? user?.id,
        createdAt:
            widget.existing?.createdAt ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '견적서 작성' : '견적서 수정'),
        actions: [TextButton(onPressed: _save, child: const Text('저장'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '고객명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '전화', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _siteCtrl,
            decoration: const InputDecoration(labelText: '현장명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: '주소', filled: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('견적일'),
            subtitle: Text(_ymd),
            trailing: const Icon(Icons.event_rounded),
            onTap: _pickYmd,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '품목',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('단가표에서 추가'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            Text(
              'A/S 단가표에서 품목을 고르거나 직접 입력합니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < _lines.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _lines[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  [
                    if (_lines[i].spec.trim().isNotEmpty) _lines[i].spec.trim(),
                    '수량 ${_lines[i].qty}',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _lines[i].amount <= 0
                          ? '-'
                          : '${_won.format(_lines[i].amount)}원',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        final next = [..._lines]..removeAt(i);
                        _lines = next;
                      }),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                onTap: () => _editLine(i),
              ),
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '합계 ${_total <= 0 ? '-' : '${_won.format(_total)}원'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '비고', filled: true),
          ),
        ],
      ),
    );
  }
}

class _SupportQuoteLineSheet extends ConsumerStatefulWidget {
  const _SupportQuoteLineSheet({this.existing});

  final SupportQuoteLine? existing;

  @override
  ConsumerState<_SupportQuoteLineSheet> createState() =>
      _SupportQuoteLineSheetState();
}

class _SupportQuoteLineSheetState
    extends ConsumerState<_SupportQuoteLineSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _specCtrl = TextEditingController(text: e?.spec ?? '');
    _qtyCtrl = TextEditingController(text: '${e?.qty ?? 1}');
    _priceCtrl = TextEditingController(
      text: e?.unitPrice == null ? '' : '${e!.unitPrice}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromPriceList() async {
    final prices = SupportUnitPriceStore(
      ref.read(appDependenciesProvider).prefs,
    ).load();
    if (prices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A/S 단가표에 품목이 없습니다. 먼저 단가를 입력해 주세요.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<SupportUnitPriceItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final rows = prices
                .where((e) => supportUnitPriceMatches(e, q))
                .toList();
            return SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '단가표 검색',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setLocal(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final item = rows[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              if (item.spec.trim().isNotEmpty) item.spec.trim(),
                              if (item.price != null) '${item.price}원',
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.pop(ctx, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _nameCtrl.text = picked.name;
      if (picked.spec.trim().isNotEmpty) _specCtrl.text = picked.spec;
      if (picked.price != null) _priceCtrl.text = '${picked.price}';
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품명을 입력해 주세요.')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
    Navigator.pop(
      context,
      SupportQuoteLine(
        name: name,
        spec: _specCtrl.text.trim(),
        qty: qty <= 0 ? 1 : qty,
        unitPrice: (price ?? 0) > 0 ? price : null,
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
          const Text(
            '품목',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickFromPriceList,
              icon: const Icon(Icons.grid_on_rounded),
              label: const Text('A/S 단가표에서 고르기'),
            ),
          ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '품명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specCtrl,
            decoration: const InputDecoration(labelText: '규격', filled: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '수량',
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '단가',
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _save, child: const Text('확인')),
          ),
        ],
      ),
    );
  }
}
