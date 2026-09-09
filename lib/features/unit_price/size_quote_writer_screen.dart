import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_export.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_promo_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<SizeQuoteDocument?> pushSizeQuoteEditor(
  BuildContext context, {
  SizeQuoteDocument? existing,
  SizeQuoteSeed? seed,
  List<SizeQuoteLine>? extraLines,
  String? initialNote,
  int? initialQuantity,
}) {
  return Navigator.of(context).push<SizeQuoteDocument>(
    MaterialPageRoute(
      builder: (_) => SizeQuoteEditorPage(
        existing: existing,
        seed: seed,
        extraLines: extraLines,
        initialNote: initialNote,
        initialQuantity: initialQuantity,
      ),
    ),
  );
}

Future<void> showSizeQuoteSimilarSheet(
  BuildContext context, {
  required List<SizeQuoteDocument> items,
  required String modelName,
  required int widthMm,
  required int heightMm,
  void Function(SizeQuoteDocument doc)? onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height * 0.72;
      return SizedBox(
        height: height,
        child: SizeQuoteSimilarList(
          items: items,
          modelName: modelName,
          widthMm: widthMm,
          heightMm: heightMm,
          onOpen: (doc) {
            Navigator.pop(ctx);
            onOpen?.call(doc);
          },
        ),
      );
    },
  );
}

class SizeQuoteWriterScreen extends ConsumerStatefulWidget {
  const SizeQuoteWriterScreen({
    super.key,
    this.seed,
    this.startNew = false,
    this.openDoc,
    this.embedded = false,
  });

  final SizeQuoteSeed? seed;
  final bool startNew;
  final SizeQuoteDocument? openDoc;

  /// 견적 탭 안: AppBar 생략, 검색·재사용 목록 중심.
  final bool embedded;

  @override
  ConsumerState<SizeQuoteWriterScreen> createState() =>
      _SizeQuoteWriterScreenState();
}

class _SizeQuoteWriterScreenState extends ConsumerState<SizeQuoteWriterScreen> {
  final _queryCtrl = TextEditingController();
  List<SizeQuoteDocument> _items = const [];
  String _query = '';
  bool _loading = true;
  Object? _error;
  final _won = NumberFormat('#,###');

  SizeQuoteRepository get _repo => ref.read(sizeQuoteRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_reload());
      if (widget.openDoc != null) {
        unawaited(_viewQuote(widget.openDoc!));
      } else if (widget.startNew || widget.seed != null) {
        unawaited(_edit(seed: widget.seed));
      }
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final remote = await _repo.list();
      if (!mounted) return;
      setState(() {
        _items = remote;
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

  List<SizeQuoteDocument> get _visible =>
      _items.where((e) => sizeQuoteMatches(e, _query)).toList();

  Future<void> _edit({
    SizeQuoteDocument? existing,
    SizeQuoteSeed? seed,
  }) async {
    final saved = await pushSizeQuoteEditor(
      context,
      existing: existing,
      seed: seed ?? widget.seed,
    );
    if (!mounted || saved == null) return;
    await _reload();
    if (!mounted) return;
    await _viewQuote(saved);
  }

  Future<void> _viewQuote(SizeQuoteDocument doc) async {
    final action = await showSizeQuoteExportSheet(context, doc: doc);
    if (!mounted) return;
    if (action == SizeQuoteViewAction.edit) {
      await _edit(existing: doc);
      return;
    }
    if (action == SizeQuoteViewAction.sent ||
        action == SizeQuoteViewAction.unsent) {
      await _reload();
    }
  }

  Future<void> _reuse(SizeQuoteDocument doc) async {
    final draft = sizeQuoteReuseAsNew(
      doc,
      newId: SizeQuoteRepository.newId(),
      ymd: todayYmdSeoul(),
    );
    await _edit(existing: draft);
  }

  Future<void> _delete(SizeQuoteDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('견적서 삭제'),
        content: Text('${doc.site.isEmpty ? doc.customerName : doc.site} 견적서를 지울까요?'),
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
    try {
      await _repo.delete(doc.id);
      await _reload();
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
    final rows = _visible;
    final groups = sizeQuoteSiteGroups(rows);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('견적서')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_edit(seed: widget.seed)),
        icon: const Icon(Icons.edit_document),
        label: const Text('새로 작성'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '현장 · 날짜 · 모델 · 사이즈 · 금액 · 작성자',
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
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '작성한 견적서를 검색·열어 재사용할 수 있습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoading(message: '견적 기록 불러오는 중…')
                : _error != null
                ? AppErrorState(
                    message: koreanErrorMessage(_error!),
                    onRetry: _reload,
                  )
                : rows.isEmpty
                ? AppEmpty(
                    icon: Icons.request_quote_outlined,
                    message: _query.trim().isEmpty
                        ? '작성한 견적서가 없습니다\n셔터 견적기·표준단가에서 견적서를 만들 수 있습니다'
                        : '검색 결과가 없습니다',
                    actionLabel: '새로 작성',
                    onAction: () => unawaited(_edit(seed: widget.seed)),
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                      itemCount: groups.length,
                      itemBuilder: (context, gi) {
                        final group = groups[gi];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                              child: Text(
                                '${group.title} · ${group.items.length}건',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            for (final doc in group.items)
                              _QuoteTile(
                                doc: doc,
                                won: _won,
                                onOpen: () => unawaited(_viewQuote(doc)),
                                onEdit: () => unawaited(_edit(existing: doc)),
                                onReuse: () => unawaited(_reuse(doc)),
                                onDelete: () => unawaited(_delete(doc)),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    required this.doc,
    required this.won,
    required this.onOpen,
    required this.onEdit,
    required this.onReuse,
    required this.onDelete,
  });

  final SizeQuoteDocument doc;
  final NumberFormat won;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onReuse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onOpen,
        title: Text(
          [
            if (doc.modelName.trim().isNotEmpty) doc.modelName.trim(),
            if (doc.sizeLabel.isNotEmpty) doc.sizeLabel,
          ].join(' · ').ifEmpty(doc.customerName),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            doc.ymd,
            if ((doc.createdBy ?? '').trim().isNotEmpty) doc.createdBy!.trim(),
            if (doc.total > 0) '${won.format(doc.total)}원',
            if (doc.hasNego) '네고 ${doc.negoSummary}',
            if (doc.isEmailSent) '메일발송',
            if (doc.isSent && !doc.isEmailSent) '발송',
            if (doc.hasCloudPdf) 'PDF',
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'reuse') onReuse();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'reuse', child: Text('다시 작성')),
            PopupMenuItem(value: 'edit', child: Text('수정')),
            PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
        leading: Icon(
          doc.isEmailSent
              ? Icons.mark_email_read_outlined
              : Icons.request_quote_outlined,
          color: doc.hasNego ? const Color(0xFFDC2626) : scheme.primary,
        ),
      ),
    );
  }
}

class SizeQuoteSimilarList extends StatelessWidget {
  const SizeQuoteSimilarList({
    super.key,
    required this.items,
    required this.modelName,
    required this.widthMm,
    required this.heightMm,
    this.onOpen,
  });

  final List<SizeQuoteDocument> items;
  final String modelName;
  final int widthMm;
  final int heightMm;
  final ValueChanged<SizeQuoteDocument>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final won = NumberFormat('#,###');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$modelName · $widthMm×$heightMm 비슷한 사이즈 견적',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? AppEmpty(
                  icon: Icons.history_outlined,
                  message: '같은 모델의 비슷한 사이즈 견적이 없습니다',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final doc = items[i];
                    return Card(
                      child: ListTile(
                        onTap: onOpen == null ? null : () => onOpen!(doc),
                        title: Text(
                          [
                            if (doc.site.trim().isNotEmpty) doc.site.trim(),
                            if (doc.customerName.trim().isNotEmpty)
                              doc.customerName.trim(),
                          ].join(' · ').ifEmpty('현장 없음'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            doc.ymd,
                            '${doc.widthMm}×${doc.heightMm}',
                            if ((doc.createdBy ?? '').trim().isNotEmpty)
                              doc.createdBy!.trim(),
                            if (doc.hasNego) '네고 ${doc.negoSummary}',
                          ].join(' · '),
                        ),
                        trailing: Text(
                          doc.total <= 0 ? '-' : '${won.format(doc.total)}원',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: doc.hasNego
                                ? const Color(0xFFDC2626)
                                : scheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SizeQuoteEditorPage extends ConsumerStatefulWidget {
  const SizeQuoteEditorPage({
    super.key,
    this.existing,
    this.seed,
    this.extraLines,
    this.initialNote,
    this.initialQuantity,
  });

  final SizeQuoteDocument? existing;
  final SizeQuoteSeed? seed;
  final List<SizeQuoteLine>? extraLines;
  final String? initialNote;
  final int? initialQuantity;

  @override
  ConsumerState<SizeQuoteEditorPage> createState() =>
      _SizeQuoteEditorPageState();
}

class _SizeQuoteEditorPageState extends ConsumerState<SizeQuoteEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _siteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _workCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _markupValueCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _negoPercentCtrl;
  late final TextEditingController _negoAmountCtrl;
  late String _ymd;
  late String _quoteNo;
  late String _id;
  bool _quoteNoAuto = true;
  late String _markupType;
  List<SizeQuoteLine> _lines = [];
  List<String> _promoIds = [];
  List<SizeQuotePromoImage> _promoCatalog = const [];
  List<SizeQuoteDocument> _similar = const [];
  final _won = NumberFormat('#,###');
  int _negoMode = 0;
  late SizeQuoteSeed _seed;

  SizeQuoteRepository get _repo => ref.read(sizeQuoteRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final seed = widget.seed ??
        SizeQuoteSeed(
          categoryId: e?.categoryId ?? '',
          categoryName: e?.categoryName ?? '',
          modelId: e?.modelId ?? '',
          modelName: e?.modelName ?? '',
          widthMm: e?.widthMm ?? 0,
          heightMm: e?.heightMm ?? 0,
          standardPrice: e?.standardPrice ?? 0,
        );
    _seed = seed;
    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _siteCtrl = TextEditingController(text: e?.site ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _noteCtrl = TextEditingController(
      text: e?.note ?? widget.initialNote ?? '',
    );
    _workCtrl = TextEditingController(
      text: e?.workName ?? '${seed.modelName} 설치 공사',
    );
    final qty = e?.quantity ?? widget.initialQuantity ?? 1;
    _qtyCtrl = TextEditingController(text: '${qty <= 0 ? 1 : qty}');
    _markupType = e?.markupType ?? kSizeQuoteMarkupNone;
    _markupValueCtrl = TextEditingController(
      text: e == null || e.markupValue == 0 ? '' : '${e.markupValue}',
    );
    _targetCtrl = TextEditingController(
      text: e?.targetTotal == null ? '' : '${e!.targetTotal}',
    );
    _ymd = e?.ymd ?? todayYmdSeoul();
    _quoteNo = e?.quoteNo ?? '';
    _quoteNoAuto = _quoteNo.trim().isEmpty;
    _id = e?.id ?? SizeQuoteRepository.newId();
    if (e?.lines.isNotEmpty == true) {
      _lines = List.of(e!.lines);
    } else {
      _lines = [
        sizeQuoteProductLine(seed: seed, quantity: qty <= 0 ? 1 : qty),
        ...?widget.extraLines,
      ];
    }
    _promoIds = List.of(e?.promoImageIds ?? const []);
    if (e == null) {
      _negoMode = 0;
    } else if (e.negoPercent > 0) {
      _negoMode = 1;
    } else if (e.negoAmount > 0) {
      _negoMode = 2;
    } else {
      _negoMode = 0;
    }
    _negoPercentCtrl = TextEditingController(
      text: e != null && e.negoPercent > 0 ? '${e.negoPercent}' : '',
    );
    _negoAmountCtrl = TextEditingController(
      text: e != null && e.negoAmount > 0 ? _won.format(e.negoAmount) : '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureQuoteNo());
      unawaited(_loadPromo());
      unawaited(_loadSimilar());
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _siteCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _workCtrl.dispose();
    _qtyCtrl.dispose();
    _markupValueCtrl.dispose();
    _targetCtrl.dispose();
    _negoPercentCtrl.dispose();
    _negoAmountCtrl.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 1;

  num get _markupValue {
    final raw = _markupValueCtrl.text.replaceAll(',', '').trim();
    return num.tryParse(raw) ?? 0;
  }

  int get _negoAmountValue {
    final raw = _negoAmountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  double get _negoPercentValue =>
      double.tryParse(_negoPercentCtrl.text.replaceAll(',', '').trim()) ?? 0;

  int? get _targetValue {
    final raw = _targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  SizeQuoteDocument _draft({String? userName}) {
    final user = userName ??
        ref.read(authControllerProvider)?.name ??
        ref.read(authControllerProvider)?.id;
    final existing = widget.existing;
    return SizeQuoteDocument(
      id: _id,
      customerName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      site: _siteCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      workName: _workCtrl.text.trim(),
      quoteNo: _quoteNo.trim().isEmpty ? '미리보기' : _quoteNo.trim(),
      ymd: _ymd,
      categoryId: _seed.categoryId,
      categoryName: _seed.categoryName,
      modelId: _seed.modelId,
      modelName: _seed.modelName,
      widthMm: _seed.widthMm,
      heightMm: _seed.heightMm,
      quantity: _qty <= 0 ? 1 : _qty,
      standardPrice: _seed.standardPrice,
      markupType: _markupType,
      markupValue: _markupValue,
      lines: List.of(_syncedLines()),
      promoImageIds: List.of(_promoIds),
      note: _noteCtrl.text.trim(),
      createdBy: (existing?.createdBy ?? '').trim().isNotEmpty
          ? existing!.createdBy
          : user,
      createdAt: existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
      updatedBy: user,
      updatedAt: existing?.updatedAt,
      sentYmd: existing?.sentYmd,
      emailSentYmd: existing?.emailSentYmd,
      negoAmount: _negoMode == 2 ? _negoAmountValue : 0,
      negoPercent: _negoMode == 1 ? _negoPercentValue : 0,
      targetTotal: _targetValue,
      editHistory: existing?.editHistory ?? const [],
      pdfPath: existing?.pdfPath,
      pdfUploadedAt: existing?.pdfUploadedAt,
      pdfUploadedBy: existing?.pdfUploadedBy,
    );
  }

  List<SizeQuoteLine> _syncedLines() {
    return sizeQuoteSyncProductLine(
      lines: _lines,
      seed: _seed,
      quantity: _qty,
      markupType: _markupType,
      markupValue: _markupValue,
    );
  }

  void _syncProduct() {
    setState(() => _lines = _syncedLines());
  }

  Future<void> _ensureQuoteNo() async {
    if (!_quoteNoAuto && _quoteNo.trim().isNotEmpty) return;
    try {
      final no = await _repo.nextQuoteNo(ymd: _ymd);
      if (!mounted) return;
      if (!_quoteNoAuto && _quoteNo.trim().isNotEmpty) return;
      setState(() {
        _quoteNo = no;
        _quoteNoAuto = true;
      });
    } catch (_) {}
  }

  Future<void> _loadPromo() async {
    if (_seed.modelId.trim().isEmpty) return;
    try {
      final items = await _repo.listPromoImages(_seed.modelId);
      if (!mounted) return;
      setState(() => _promoCatalog = items);
    } catch (_) {}
  }

  Future<void> _loadSimilar() async {
    if (_seed.modelId.trim().isEmpty) return;
    try {
      final items = await _repo.listSimilar(
        modelId: _seed.modelId,
        widthMm: _seed.widthMm,
        heightMm: _seed.heightMm,
        excludeId: widget.existing?.id,
      );
      if (!mounted) return;
      setState(() => _similar = items);
    } catch (_) {}
  }

  Future<void> _pickYmd() async {
    final initial = DateTime.tryParse(_ymd) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _ymd = DateFormat('yyyy-MM-dd').format(picked));
    if (_quoteNoAuto || _quoteNo.trim().isEmpty) {
      unawaited(_ensureQuoteNo());
    }
  }

  Future<void> _addLine(String kind) async {
    final line = await showModalBottomSheet<SizeQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      builder: (_) => _SizeQuoteLineSheet(kind: kind),
    );
    if (line == null || !mounted) return;
    setState(() => _lines = [..._syncedLines(), line]);
  }

  Future<void> _editLine(int index) async {
    final current = _syncedLines();
    final line = await showModalBottomSheet<SizeQuoteLine>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      builder: (_) => _SizeQuoteLineSheet(existing: current[index]),
    );
    if (line == null || !mounted) return;
    setState(() {
      final next = [...current];
      next[index] = line;
      _lines = next;
    });
  }

  void _removeLine(int index) {
    final current = _syncedLines();
    if (current[index].isProduct) return;
    setState(() {
      final next = [...current]..removeAt(index);
      _lines = next;
    });
  }

  void _fitTarget() {
    final target = _targetValue;
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('목표 총액을 입력해 주세요.')),
      );
      return;
    }
    final fitted = sizeQuoteFitToTarget(_draft(), target);
    setState(() {
      _lines = fitted.lines;
      _targetCtrl.text = _won.format(target);
    });
  }

  Future<void> _save({bool send = false}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('고객명을 입력해 주세요.')),
      );
      return;
    }
    try {
      final user = ref.read(authControllerProvider);
      final stored = await _repo.upsert(
        _draft(userName: user?.name ?? user?.id),
        editorName: user?.name ?? user?.id,
      );
      if (!mounted) return;
      if (!send) {
        Navigator.of(context).pop(stored);
        return;
      }
      final action = await showSizeQuoteExportSheet(context, doc: stored);
      if (!mounted) return;
      if (action == SizeQuoteViewAction.edit) return;
      Navigator.of(context).pop(stored);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _preview() async {
    HapticFeedback.selectionClick();
    final saveAndSend = await showSizeQuotePreviewSheet(
      context,
      doc: _draft(),
    );
    if (!mounted || !saveAndSend) return;
    await _save(send: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doc = _draft();
    final remaining = doc.remainingToTarget;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '견적서 작성' : '견적서 수정'),
        actions: [
          IconButton(
            tooltip: '미리보기',
            onPressed: () => unawaited(_preview()),
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: '저장하고 보내기',
            onPressed: () => unawaited(_save(send: true)),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _sectionTitle('고객 · 현장'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '고객명', filled: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '전화', filled: true),
            onChanged: (value) {
              final formatted = formatKoreanPhoneHyphenated(value);
              if (formatted != value) {
                _phoneCtrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              hintText: '메일 발송 주소 (선택)',
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _siteCtrl,
            decoration: const InputDecoration(labelText: '현장명', filled: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _workCtrl,
            decoration: const InputDecoration(labelText: '공사명', filled: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: '주소', filled: true),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickYmd,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '견적일',
                filled: true,
              ),
              child: Text(_ymd, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '견적번호 ${_quoteNo.trim().isEmpty ? '저장 시 자동' : _quoteNo}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('표준단가 · 마진'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_seed.categoryName} / ${_seed.modelName}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_seed.widthMm}×${_seed.heightMm} · 표준 ${_won.format(_seed.standardPrice)}원',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: kSizeQuoteMarkupNone,
                        label: Text(
                          '그대로',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: kSizeQuoteMarkupPercent,
                        label: Text(
                          '+%',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: kSizeQuoteMarkupAmount,
                        label: Text(
                          '+금액',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                    selected: {_markupType},
                    onSelectionChanged: (s) {
                      setState(() {
                        _markupType = s.first;
                        if (_markupType == kSizeQuoteMarkupNone) {
                          _markupValueCtrl.clear();
                        }
                      });
                      _syncProduct();
                    },
                  ),
                  if (_markupType != kSizeQuoteMarkupNone) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _markupValueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _markupType == kSizeQuoteMarkupPercent
                            ? '가산율'
                            : '가산 금액',
                        suffixText: _markupType == kSizeQuoteMarkupPercent
                            ? '%'
                            : '원',
                        filled: true,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _syncProduct();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '수량',
                      suffixText: 'SET',
                      filled: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _syncProduct();
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '판매단가 ${_won.format(doc.sellingUnitPrice)}원'
                      '${doc.markupSummary.isEmpty ? '' : ' (${doc.markupSummary})'}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => unawaited(
                showSizeQuoteSimilarSheet(
                  context,
                  items: _similar,
                  modelName: _seed.modelName,
                  widthMm: _seed.widthMm,
                  heightMm: _seed.heightMm,
                  onOpen: (other) => unawaited(
                    showSizeQuoteExportSheet(context, doc: other),
                  ),
                ),
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text(
                '같은 모델 비슷한 사이즈 ${_similar.length}건 · 누가 얼마였는지',
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final kind in kSizeQuoteKindOrder) ...[
            Row(
              children: [
                Expanded(child: _sectionTitle(sizeQuoteKindLabel(kind))),
                TextButton.icon(
                  onPressed: () => unawaited(_addLine(kind)),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
            if (doc.linesOfKind(kind).isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  kind == kSizeQuoteKindMain
                      ? '본체는 표준단가에서 자동으로 들어갑니다.'
                      : '${sizeQuoteKindLabel(kind)} 항목을 추가하세요.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final line in doc.lines.asMap().entries)
                if (line.value.kind == kind)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      line.value.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        if (line.value.spec.trim().isNotEmpty)
                          line.value.spec.trim(),
                        if (line.value.unit.trim().isNotEmpty)
                          line.value.unit.trim(),
                        '수량 ${line.value.qty}',
                        if (line.value.isProduct) '본체',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line.value.amount <= 0
                              ? '-'
                              : '${_won.format(line.value.amount)}원',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (!line.value.isProduct)
                          IconButton(
                            onPressed: () => _removeLine(line.key),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                    onTap: line.value.isProduct
                        ? null
                        : () => unawaited(_editLine(line.key)),
                  ),
          ],
          const SizedBox(height: 8),
          _sectionTitle('전체금액 맞추기'),
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '목표 총액',
              hintText: '정해진 전체금액',
              suffixText: '원',
              filled: true,
            ),
            onChanged: (v) {
              final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
              final n = int.tryParse(digits);
              if (n != null && n > 0) {
                final formatted = _won.format(n);
                if (formatted != v) {
                  _targetCtrl.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  remaining == null
                      ? '현재 ${_won.format(doc.total)}원'
                      : remaining == 0
                      ? '목표와 같습니다'
                      : remaining > 0
                      ? '남은 ${_won.format(remaining)}원'
                      : '초과 ${_won.format(-remaining)}원',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: remaining == null || remaining == 0
                        ? scheme.onSurface
                        : remaining > 0
                        ? scheme.primary
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: _fitTarget,
                child: const Text('나머지 맞추기'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionTitle('네고'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('없음')),
              ButtonSegment(value: 1, label: Text('%')),
              ButtonSegment(value: 2, label: Text('금액')),
            ],
            selected: {_negoMode},
            onSelectionChanged: (s) {
              setState(() {
                _negoMode = s.first;
                if (_negoMode != 1) _negoPercentCtrl.clear();
                if (_negoMode != 2) _negoAmountCtrl.clear();
              });
            },
          ),
          if (_negoMode == 1) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _negoPercentCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '네고 할인율',
                suffixText: '%',
                filled: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_negoMode == 2) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _negoAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '네고 금액',
                suffixText: '원',
                filled: true,
              ),
              onChanged: (v) {
                final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                final n = int.tryParse(digits);
                if (n != null && n > 0) {
                  final formatted = _won.format(n);
                  if (formatted != v) {
                    _negoAmountCtrl.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                }
                setState(() {});
              },
            ),
          ],
          if (doc.hasNego) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '네고 −${_won.format(doc.negoOff)}원 ${doc.negoSummary}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '최종 ${doc.total <= 0 ? '-' : '${_won.format(doc.total)}원'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _sectionTitle('홍보 이미지 (다음장)')),
              TextButton.icon(
                onPressed: _seed.modelId.isEmpty
                    ? null
                    : () async {
                        await pushSizeQuotePromoScreen(
                          context,
                          modelId: _seed.modelId,
                          modelName: _seed.modelName,
                        );
                        if (mounted) unawaited(_loadPromo());
                      },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('추가·수정·삭제'),
              ),
            ],
          ),
          if (_promoCatalog.isEmpty)
            Text(
              '이 모델 홍보 이미지가 없습니다. 「추가·수정·삭제」에서 따로 관리하세요.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final image in _promoCatalog)
                  FilterChip(
                    selected: _promoIds.contains(image.id),
                    onSelected: (on) {
                      setState(() {
                        if (on) {
                          _promoIds = [..._promoIds, image.id];
                        } else {
                          _promoIds = _promoIds
                              .where((e) => e != image.id)
                              .toList();
                        }
                      });
                    },
                    avatar: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CachedAppImage(
                          url: _repo.publicPromoUrl(image.storagePath),
                          memCacheWidth: 80,
                        ),
                      ),
                    ),
                    label: Text(
                      image.title.trim().isEmpty ? '이미지' : image.title.trim(),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '비고', filled: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => unawaited(_preview()),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('견적서 미리보기'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => unawaited(_save(send: true)),
            icon: const Icon(Icons.send_rounded),
            label: const Text('저장하고 이미지·PDF·메일'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SizeQuoteLineSheet extends StatefulWidget {
  const _SizeQuoteLineSheet({this.existing, this.kind});

  final SizeQuoteLine? existing;
  final String? kind;

  @override
  State<_SizeQuoteLineSheet> createState() => _SizeQuoteLineSheetState();
}

class _SizeQuoteLineSheetState extends State<_SizeQuoteLineSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;
  late String _kind;
  final _won = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _specCtrl = TextEditingController(text: e?.spec ?? '');
    _unitCtrl = TextEditingController(
      text: e?.unit ?? (widget.kind == kSizeQuoteKindMain ? 'SET' : 'EA'),
    );
    _qtyCtrl = TextEditingController(text: '${e?.qty ?? 1}');
    _priceCtrl = TextEditingController(
      text: e?.unitPrice == null ? '' : _won.format(e!.unitPrice),
    );
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _kind = e?.kind ?? widget.kind ?? kSizeQuoteKindOther;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품명을 입력해 주세요.')));
      return;
    }
    final qty = int.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 1;
    final price = int.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    Navigator.pop(
      context,
      SizeQuoteLine(
        name: name,
        spec: _specCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'EA' : _unitCtrl.text.trim(),
        qty: qty <= 0 ? 1 : qty,
        unitPrice: price,
        note: _noteCtrl.text.trim(),
        kind: _kind,
        isProduct: widget.existing?.isProduct ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = MediaQuery.sizeOf(context);
            final pad = MediaQuery.paddingOf(context);
            final sheetH = constraints.maxHeight.isFinite &&
                    constraints.maxHeight > 0
                ? constraints.maxHeight
                : ((size.height - keyboard - pad.bottom) * 0.9)
                    .clamp(280.0, size.height);
            return SizedBox(
              height: sheetH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    widget.existing == null ? '품목 추가' : '품목 수정',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: [
                              for (final kind in kSizeQuoteKindOrder)
                                ButtonSegment(
                                  value: kind,
                                  label: Text(
                                    sizeQuoteKindLabel(kind),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ),
                            ],
                            selected: {_kind},
                            onSelectionChanged: (s) =>
                                setState(() => _kind = s.first),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameCtrl,
                            autofocus: widget.existing == null,
                            decoration: const InputDecoration(
                              labelText: '품명',
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _specCtrl,
                            decoration: const InputDecoration(
                              labelText: '규격',
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue:
                                      kSizeQuoteUnits.contains(_unitCtrl.text)
                                      ? _unitCtrl.text
                                      : 'EA',
                                  items: [
                                    for (final u in kSizeQuoteUnits)
                                      DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    _unitCtrl.text = v;
                                    setState(() {});
                                  },
                                  decoration: const InputDecoration(
                                    labelText: '단위',
                                    filled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '수량',
                                    filled: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '단가',
                              suffixText: '원',
                              filled: true,
                            ),
                            onChanged: (v) {
                              final digits =
                                  v.replaceAll(RegExp(r'[^0-9]'), '');
                              final n = int.tryParse(digits);
                              if (n != null && n > 0) {
                                final formatted = _won.format(n);
                                if (formatted != v) {
                                  _priceCtrl.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                      offset: formatted.length,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              labelText: '비고',
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Material(
                    elevation: 2,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(
                          widget.existing == null ? '추가' : '저장',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
