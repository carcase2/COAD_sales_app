import 'dart:async';
import 'dart:convert';

import 'package:coad_customer_calls/core/utils/business_card_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/features/business_cards/business_card_fill_sheet.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/cached_app_image.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/quoter/quote_product_picker.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_draft_store.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_product_pick.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_export.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_note_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_office_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_promo_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 작성 화면을 닫을 때. [openExport]면 목록에서 이미지·PDF 화면을 연다.
class SizeQuoteEditorResult {
  const SizeQuoteEditorResult(this.doc, {this.openExport = false});

  final SizeQuoteDocument doc;
  final bool openExport;
}

Future<SizeQuoteEditorResult?> pushSizeQuoteEditor(
  BuildContext context, {
  SizeQuoteDocument? existing,
  SizeQuoteSeed? seed,
  List<SizeQuoteLine>? extraLines,
  String? initialNote,
  int? initialQuantity,
  SizeQuoteDraft? draft,
}) {
  return Navigator.of(context).push<SizeQuoteEditorResult>(
    MaterialPageRoute(
      builder: (_) => SizeQuoteEditorPage(
        existing: draft?.doc ?? existing,
        seed: seed,
        extraLines: extraLines,
        initialNote: initialNote,
        initialQuantity: initialQuantity,
        resumingNewDraft: draft?.isNew ?? false,
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
  List<SizeQuoteDraft> _drafts = const [];
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
      } else if (widget.startNew) {
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
    unawaited(_reloadDrafts());
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

  Future<void> _reloadDrafts() async {
    final store = await SizeQuoteDraftStore.open();
    if (!mounted) return;
    setState(() => _drafts = store.load());
  }

  /// 「새로 작성」: 표준단가에서 왔으면 그 모델로 바로, 아니면 제품부터 고른다.
  Future<void> _startNew() async {
    if (widget.seed != null) {
      await _edit(seed: widget.seed);
      return;
    }
    final pick = await showQuoteProductPicker(context);
    if (!mounted || pick == null) return;
    await _edit(
      seed: pick.seed,
      extraLines: pick.extraLines,
      note: pick.note,
      quantity: pick.quantity,
    );
  }

  Future<void> _resumeDraft(SizeQuoteDraft draft) async {
    await _edit(draft: draft);
  }

  Future<void> _dropDraft(SizeQuoteDraft draft) async {
    final store = await SizeQuoteDraftStore.open();
    await store.remove(draft.doc.id);
    await _reloadDrafts();
  }

  List<SizeQuoteDocument> get _visible =>
      _items.where((e) => sizeQuoteMatches(e, _query)).toList();

  Future<void> _edit({
    SizeQuoteDocument? existing,
    SizeQuoteSeed? seed,
    List<SizeQuoteLine>? extraLines,
    String? note,
    int? quantity,
    SizeQuoteDraft? draft,
  }) async {
    final saved = await pushSizeQuoteEditor(
      context,
      existing: existing,
      seed: draft == null ? (seed ?? widget.seed) : null,
      extraLines: extraLines,
      initialNote: (note ?? '').trim().isEmpty ? null : note,
      initialQuantity: quantity,
      draft: draft,
    );
    if (!mounted) return;
    if (saved == null) {
      await _reloadDrafts();
      return;
    }
    await _reload();
    if (!mounted) return;
    if (saved.openExport) {
      await _viewQuote(saved.doc);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('견적서를 저장했습니다.')));
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
        content: Text(
          '${doc.site.isEmpty ? doc.customerName : doc.site} 견적서를 지울까요?',
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
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(
        doc.id,
        by: sizeQuoteLoginStaffLabel(ref.read(authControllerProvider)),
      );
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
      appBar: widget.embedded ? null : AppBar(title: const Text('견적서')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_startNew()),
        icon: const Icon(Icons.edit_document),
        label: const Text('새 견적서'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '현장 · 고객 · 날짜 · 모델 · 작성자',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: [
                if (_query.trim().isNotEmpty)
                  IconButton(
                    tooltip: '검색 지우기',
                    onPressed: () {
                      _queryCtrl.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
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
          if (_drafts.isNotEmpty && _query.trim().isEmpty)
            _DraftStrip(
              drafts: _drafts,
              onOpen: (d) => unawaited(_resumeDraft(d)),
              onDrop: (d) => unawaited(_dropDraft(d)),
            ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _query.trim().isEmpty
                      ? '전체 ${_items.length}건 · 누르면 보기, 수정은 버튼'
                      : '검색 ${rows.length}건',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
                        ? '작성한 견적서가 없습니다\n「새 견적서」에서 표준단가·셔터 제품을 골라 시작하세요'
                        : '검색 결과가 없습니다',
                    actionLabel: '새 견적서',
                    onAction: () => unawaited(_startNew()),
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
                              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                              child: Text(
                                '${group.title} · ${group.items.length}건',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
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

/// 임시저장한 견적서. 목록 위에 가로로 둔다.
class _DraftStrip extends StatelessWidget {
  const _DraftStrip({
    required this.drafts,
    required this.onOpen,
    required this.onDrop,
  });

  final List<SizeQuoteDraft> drafts;
  final ValueChanged<SizeQuoteDraft> onOpen;
  final ValueChanged<SizeQuoteDraft> onDrop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '작성 중 ${drafts.length}건 · 이 기기에만 있음',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: drafts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = drafts[i];
                final doc = d.doc;
                final who = [
                  doc.site.trim(),
                  doc.customerName.trim(),
                ].where((e) => e.isNotEmpty).join(' · ');
                final what = [
                  doc.modelName.trim(),
                  doc.sizeLabel,
                ].where((e) => e.isNotEmpty).join(' ');
                return Material(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onOpen(d),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
                      child: Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  who.isEmpty ? '고객 미입력' : who,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  [
                                    if (!d.isNew) '수정 중',
                                    if (what.isNotEmpty) what,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '임시저장 지우기',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDrop(d),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
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
    final site = doc.site.trim().isNotEmpty
        ? doc.site.trim()
        : (doc.customerName.trim().isEmpty ? '현장 없음' : doc.customerName.trim());
    final author = (doc.createdBy ?? '').trim();
    final sizes = sizeQuoteSizeListLabel(doc);
    final model = [
      if (doc.modelName.trim().isNotEmpty) doc.modelName.trim(),
      if (sizes.isNotEmpty) sizes,
    ].join(' · ');
    final customer = doc.customerName.trim();
    final showCustomer = customer.isNotEmpty && customer != site;
    final muted = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: scheme.onSurfaceVariant,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LabeledLine(
                      label: '현장명',
                      value: site,
                      valueStyle: const TextStyle(
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                      labelStyle: muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LabeledLine(
                    label: '날짜',
                    value: _quoteListDate(doc.ymd),
                    alignEnd: true,
                    valueStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                    labelStyle: muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _LabeledLine(
                label: '작성자',
                value: author.isEmpty ? '없음' : author,
                valueStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: author.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
                labelStyle: muted,
              ),
              if (showCustomer) ...[
                const SizedBox(height: 4),
                _LabeledLine(
                  label: '고객',
                  value: customer,
                  valueStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  labelStyle: muted,
                ),
              ],
              if (model.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  model,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          doc.total <= 0 ? '-' : '${won.format(doc.total)}원',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (doc.isDetailQuote) _QuoteMark('세부', scheme.primary),
                        if (doc.hasNego)
                          _QuoteMark('네고 ${doc.negoSummary}', scheme.error),
                        if (doc.isEmailSent) _QuoteMark('메일', scheme.primary),
                        if (doc.isSent && !doc.isEmailSent)
                          _QuoteMark('발송', scheme.primary),
                        if (doc.hasCloudPdf) _QuoteMark('PDF', scheme.primary),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      '수정',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '더보기',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (v) {
                      if (v == 'open') onOpen();
                      if (v == 'reuse') onReuse();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('보기')),
                      PopupMenuItem(value: 'reuse', child: Text('다시 작성')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledLine extends StatelessWidget {
  const _LabeledLine({
    required this.label,
    required this.value,
    required this.valueStyle,
    required this.labelStyle,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final TextStyle valueStyle;
  final TextStyle labelStyle;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        Text(
          value,
          maxLines: alignEnd ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: valueStyle,
        ),
      ],
    );
  }
}

String _quoteListDate(String ymd) {
  final raw = ymd.trim();
  if (raw.isEmpty) return '날짜 없음';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('yyyy.MM.dd').format(parsed);
}

class _QuoteMark extends StatelessWidget {
  const _QuoteMark(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
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

enum _CardLookup { name, phone, email }

class SizeQuoteEditorPage extends ConsumerStatefulWidget {
  const SizeQuoteEditorPage({
    super.key,
    this.existing,
    this.seed,
    this.extraLines,
    this.initialNote,
    this.initialQuantity,
    this.resumingNewDraft = false,
  });

  final SizeQuoteDocument? existing;
  final SizeQuoteSeed? seed;
  final List<SizeQuoteLine>? extraLines;
  final String? initialNote;
  final int? initialQuantity;

  /// 임시저장한 새 견적서를 이어 쓰는 중. [existing]은 그 초안이고 서버에는 아직 없다.
  final bool resumingNewDraft;

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
  late final TextEditingController _markupPercentCtrl;
  late final TextEditingController _markupAmountCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _targetUnitCtrl;
  late final TextEditingController _sensorCtrl;
  late final TextEditingController _installCtrl;
  late final TextEditingController _transportCtrl;
  bool _detail = false;
  bool _suppressMoney = false;
  Timer? _cardLookupDebounce;
  int _cardLookupToken = 0;
  bool _cardLookupBusy = false;
  bool _applyingCard = false;
  bool _cardSheetOpen = false;
  _CardLookup? _cardLookupField;
  _CardLookup? _pendingCardField;
  String? _pendingCardQuery;
  String? _cardPromptKey;
  BusinessCard? _matchedCard;
  List<BusinessCardFill> _cardChoices = const [];

  late String _ymd;
  late String _quoteNo;
  late String _id;
  bool _quoteNoAuto = true;

  List<SizeQuoteLine> _lines = [];
  final List<_ExtraSizeForm> _extraSizes = [];
  bool _addingSize = false;
  List<StandardPriceCell>? _modelCells;
  List<String> _promoIds = [];
  List<SizeQuotePromoImage> _promoCatalog = const [];
  List<SizeQuoteDocument> _similar = const [];
  final _won = NumberFormat('#,###');
  late SizeQuoteSeed _seed;

  /// 연 순간의 내용. 닫을 때 이것과 다르면 임시저장을 묻는다.
  String _openingSignature = '';
  bool _leaving = false;

  SizeQuoteRepository get _repo => ref.read(sizeQuoteRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final seed =
        widget.seed ??
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
      text: sizeQuoteResolvedWorkName(
        workName: e?.workName ?? '',
        categoryName: seed.categoryName,
        modelName: seed.modelName,
      ),
    );
    final qty = e?.quantity ?? widget.initialQuantity ?? 1;
    _qtyCtrl = TextEditingController(text: '${qty <= 0 ? 1 : qty}');
    final savedPercent = e == null
        ? 0
        : (e.markupPercent != 0
              ? e.markupPercent
              : (e.markupType == kSizeQuoteMarkupPercent ||
                        e.markupType == kSizeQuoteMarkupBoth
                    ? e.markupValue
                    : 0));
    final savedAmount = e == null
        ? 0
        : (e.markupAmount != 0
              ? e.markupAmount
              : (e.markupType == kSizeQuoteMarkupAmount
                    ? e.markupValue.round()
                    : 0));
    _markupPercentCtrl = TextEditingController(
      text: _signedPercentText(savedPercent),
    );
    _markupAmountCtrl = TextEditingController(
      text: savedAmount == 0 ? '' : _won.format(savedAmount),
    );
    _targetCtrl = TextEditingController(
      text: e?.targetTotal == null ? '' : '${e!.targetTotal}',
    );
    final openingDetail = e != null && sizeQuoteLinesAreDetail(e.lines);
    final openingGroups = e == null
        ? const <SizeQuoteSizeGroup>[]
        : sizeQuoteSizesOf(e);
    final openingPrimary = openingGroups.isEmpty ? null : openingGroups.first;
    final openingSensor = openingDetail
        ? (openingPrimary?.sensor ??
              sizeQuoteDetailUnitPrice(e.lines, kSizeQuoteDetailSensor))
        : kSizeQuoteDefaultSensor;
    final openingInstall = openingDetail
        ? (openingPrimary?.install ??
              sizeQuoteDetailUnitPrice(e.lines, kSizeQuoteDetailInstall))
        : kSizeQuoteDefaultInstall;
    final openingTransport = openingDetail
        ? (openingPrimary?.transport ??
              sizeQuoteDetailUnitPrice(e.lines, kSizeQuoteDetailTransport))
        : kSizeQuoteDefaultTransport;
    final openingBody = openingDetail
        ? (openingPrimary?.bodyUnit ??
              sizeQuoteDetailUnitPrice(e.lines, kSizeQuoteDetailBody))
        : 0;
    final openingDetailSum =
        openingBody + openingSensor + openingInstall + openingTransport;
    final openingSelling = e == null
        ? seed.standardPrice
        : sizeQuoteApplyMarkup(
            standardPrice: seed.standardPrice,
            markupType: e.markupType,
            markupValue: e.markupValue,
            percent: savedPercent,
            amount: savedAmount,
          );
    _detail = openingDetail;
    final openingTarget = openingDetail && openingDetailSum > 0
        ? openingDetailSum
        : openingSelling;
    _targetUnitCtrl = TextEditingController(
      text: openingTarget <= 0 ? '' : _won.format(openingTarget),
    );
    _sensorCtrl = TextEditingController(
      text: openingSensor <= 0 ? '' : _won.format(openingSensor),
    );
    _installCtrl = TextEditingController(
      text: openingInstall <= 0 ? '' : _won.format(openingInstall),
    );
    _transportCtrl = TextEditingController(
      text: openingTransport <= 0 ? '' : _won.format(openingTransport),
    );
    _ymd = e?.ymd ?? todayYmdSeoul();
    final openingNo = (e?.quoteNo ?? '').trim();
    _quoteNo = openingNo == '미리보기' ? '' : openingNo;
    _quoteNoAuto = _quoteNo.trim().isEmpty;
    _id = e?.id ?? SizeQuoteRepository.newId();
    if (e?.lines.isNotEmpty == true) {
      _lines = List.of(e!.lines);
    } else {
      _lines = [
        if (!seed.isEmpty)
          sizeQuoteProductLine(seed: seed, quantity: qty <= 0 ? 1 : qty),
        ...?widget.extraLines,
      ];
    }
    for (final group in openingGroups.skip(1)) {
      _extraSizes.add(_ExtraSizeForm.fromGroup(group, _won));
    }
    _promoIds = List.of(e?.promoImageIds ?? const []);
    _openingSignature = _signature();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_ensureQuoteNo());
      unawaited(_loadPromo());
      unawaited(_loadSimilar());
    });
  }

  @override
  void dispose() {
    _cardLookupDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _siteCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _workCtrl.dispose();
    _qtyCtrl.dispose();
    _markupPercentCtrl.dispose();
    _markupAmountCtrl.dispose();
    _targetCtrl.dispose();
    _targetUnitCtrl.dispose();
    _sensorCtrl.dispose();
    _installCtrl.dispose();
    _transportCtrl.dispose();
    for (final extra in _extraSizes) {
      extra.dispose();
    }
    super.dispose();
  }

  void _setField(TextEditingController ctrl, String value) {
    ctrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _onCustomerNameChanged(String value) {
    if (_applyingCard) return;
    setState(() {});
    _scheduleCardLookup(_CardLookup.name, value);
  }

  void _onCustomerPhoneChanged(String value) {
    if (_applyingCard) return;
    final formatted = formatKoreanPhoneHyphenated(value);
    if (formatted != value) _setField(_phoneCtrl, formatted);
    setState(() {});
    _scheduleCardLookup(_CardLookup.phone, formatted);
  }

  void _onCustomerEmailChanged(String value) {
    if (_applyingCard) return;
    setState(() {});
    _scheduleCardLookup(_CardLookup.email, value);
  }

  bool _cardQueryReady(_CardLookup field, String query) {
    switch (field) {
      case _CardLookup.name:
        return query.trim().length >= 2;
      case _CardLookup.phone:
        return normalizePhoneDigits(query).length >= 8;
      case _CardLookup.email:
        final q = query.trim().toLowerCase();
        return q.contains('@') && q.length >= 5;
    }
  }

  void _scheduleCardLookup(_CardLookup field, String raw) {
    _cardLookupDebounce?.cancel();
    final query = raw.trim();
    if (!_cardQueryReady(field, query)) {
      if (_cardLookupField == field &&
          (_matchedCard != null ||
              _cardLookupBusy ||
              _cardChoices.isNotEmpty)) {
        setState(() {
          _matchedCard = null;
          _cardLookupBusy = false;
          _cardLookupField = null;
          _cardPromptKey = null;
          _cardChoices = const [];
        });
      }
      return;
    }
    _cardLookupDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_lookupCard(field, query));
    });
  }

  Future<void> _lookupCard(_CardLookup field, String query) async {
    if (_cardSheetOpen) {
      _pendingCardField = field;
      _pendingCardQuery = query;
      return;
    }
    final user = ref.read(authControllerProvider);
    if (user == null || !canAccessBusinessCards(user)) return;
    final token = ++_cardLookupToken;
    final key = '${field.name}:$query';
    setState(() {
      _cardLookupBusy = true;
      _cardLookupField = field;
    });
    try {
      final repo = ref.read(businessCardRepositoryProvider);
      final found = switch (field) {
        _CardLookup.name => await repo.findByName(user: user, name: query),
        _CardLookup.phone => await repo.findByPhone(user: user, phone: query),
        _CardLookup.email => await repo.findByEmail(user: user, email: query),
      };
      if (!mounted || token != _cardLookupToken) return;
      final choices = switch (field) {
        _CardLookup.name => businessCardFillChoices(query, found),
        _CardLookup.phone => businessCardFillsForPhone(query, found),
        _CardLookup.email => businessCardFillsOf(found),
      };
      if (choices.isEmpty) {
        setState(() {
          _matchedCard = null;
          _cardLookupBusy = false;
          _cardChoices = const [];
          _cardPromptKey = null;
        });
        return;
      }
      setState(() {
        _cardChoices = choices;
        _cardLookupBusy = false;
        if (choices.length > 1) _matchedCard = null;
      });
      if (choices.length == 1) {
        _applyCard(choices.first);
        _cardPromptKey = key;
        return;
      }
      if (_cardPromptKey == key) return;
      _cardPromptKey = key;
      _cardSheetOpen = true;
      final pick = await showBusinessCardFillSheet(context, choices: choices);
      _cardSheetOpen = false;
      if (!mounted) return;
      if (token == _cardLookupToken && pick != null) _applyCard(pick);
      final pendingField = _pendingCardField;
      final pendingQuery = _pendingCardQuery;
      _pendingCardField = null;
      _pendingCardQuery = null;
      if (pendingField != null &&
          pendingQuery != null &&
          pendingQuery != query) {
        unawaited(_lookupCard(pendingField, pendingQuery));
      }
    } catch (_) {
      _cardSheetOpen = false;
      if (!mounted || token != _cardLookupToken) return;
      setState(() {
        _matchedCard = null;
        _cardLookupBusy = false;
      });
    }
  }

  void _applyCard(BusinessCardFill pick) {
    _applyingCard = true;
    final card = pick.card;
    final cardName = card.name.trim();
    if (cardName.isNotEmpty) _setField(_nameCtrl, cardName);
    if (pick.phone.trim().isNotEmpty) {
      _setField(_phoneCtrl, formatKoreanPhoneHyphenated(pick.phone));
    }
    final email = card.email.trim();
    if (email.isNotEmpty) _setField(_emailCtrl, email);
    if (_addressCtrl.text.trim().isEmpty && card.address.trim().isNotEmpty) {
      _setField(_addressCtrl, card.address.trim());
    }
    if (_siteCtrl.text.trim().isEmpty && card.company.trim().isNotEmpty) {
      _setField(_siteCtrl, card.company.trim());
    }
    _applyingCard = false;
    setState(() => _matchedCard = card);
  }

  Future<void> _repickCard() async {
    if (_cardChoices.length < 2 || _cardSheetOpen) return;
    _cardSheetOpen = true;
    final pick = await showBusinessCardFillSheet(
      context,
      choices: _cardChoices,
    );
    _cardSheetOpen = false;
    if (!mounted || pick == null) return;
    _applyCard(pick);
  }

  Widget? _cardSuffix(_CardLookup field) {
    if (!_cardLookupBusy || _cardLookupField != field) return null;
    return const Padding(
      padding: EdgeInsets.all(12),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  int get _qty =>
      int.tryParse(_qtyCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 1;

  num get _markupPercent =>
      num.tryParse(_markupPercentCtrl.text.replaceAll(',', '').trim()) ?? 0;

  int get _markupAmount =>
      int.tryParse(_markupAmountCtrl.text.replaceAll(RegExp(r'[^0-9-]'), '')) ??
      0;

  String get _markupType {
    if (_markupPercent != 0 && _markupAmount != 0) return kSizeQuoteMarkupBoth;
    if (_markupPercent != 0) return kSizeQuoteMarkupPercent;
    if (_markupAmount != 0) return kSizeQuoteMarkupAmount;
    return kSizeQuoteMarkupNone;
  }

  num get _markupValue =>
      _markupType == kSizeQuoteMarkupAmount ? _markupAmount : _markupPercent;

  int get _currentSelling => sizeQuoteApplyMarkup(
    standardPrice: _seed.standardPrice,
    markupType: _markupType,
    markupValue: _markupValue,
    percent: _markupPercent,
    amount: _markupAmount,
  );

  int _parsedMoney(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get _detailExtras =>
      _parsedMoney(_sensorCtrl) +
      _parsedMoney(_installCtrl) +
      _parsedMoney(_transportCtrl);

  /// 세부 항목이 입력한 목표보다 크면 견적 단가는 세부 합계를 따른다.
  int get _resolvedDetailTarget {
    final typed = _parsedMoney(_targetUnitCtrl);
    final extras = _detailExtras;
    if (typed < extras) return extras;
    return typed;
  }

  int get _bodyUnit {
    final body = _resolvedDetailTarget - _detailExtras;
    return body < 0 ? 0 : body;
  }

  bool get _basicTargetPending {
    if (_detail || _seed.standardPrice <= 0) return false;
    final typed = _parsedMoney(_targetUnitCtrl);
    return typed > 0 && typed != _currentSelling;
  }

  int? get _targetValue {
    final raw = _targetCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  String _staffName() =>
      sizeQuoteLoginStaffLabel(ref.read(authControllerProvider));

  String _createdBy(String staff) {
    final existingName = (widget.existing?.createdBy ?? '').trim();
    final id = ref.read(authControllerProvider)?.id.trim() ?? '';
    if (existingName.isEmpty) return staff;
    if (id.isNotEmpty && existingName == id && staff.isNotEmpty) return staff;
    return existingName;
  }

  SizeQuoteDocument _draft({String? userName}) {
    final named = (userName ?? '').trim();
    final user = named.isNotEmpty ? named : _staffName();
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
      markupType: _detail
          ? (_detailMarkupAmount == 0
                ? kSizeQuoteMarkupNone
                : kSizeQuoteMarkupAmount)
          : _markupType,
      markupValue: _detail ? _detailMarkupAmount : _markupValue,
      markupPercent: _detail ? 0 : _markupPercent,
      markupAmount: _detail ? _detailMarkupAmount : _markupAmount,
      lines: List.of(_syncedLines()),
      promoImageIds: List.of(_promoIds),
      note: _noteCtrl.text.trim(),
      createdBy: _createdBy(user),
      createdAt:
          existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
      updatedBy: user,
      updatedAt: existing?.updatedAt,
      sentYmd: existing?.sentYmd,
      emailSentYmd: existing?.emailSentYmd,
      negoAmount: 0,
      negoPercent: 0,
      targetTotal: _detail ? _detailQuoteTarget() : _targetValue,
      editHistory: existing?.editHistory ?? const [],
      pdfPath: existing?.pdfPath,
      pdfUploadedAt: existing?.pdfUploadedAt,
      pdfUploadedBy: existing?.pdfUploadedBy,
    );
  }

  int get _detailMarkupAmount => _resolvedDetailTarget - _seed.standardPrice;

  int _detailQuoteTarget() {
    final qty = _qty <= 0 ? 1 : _qty;
    var sum = _resolvedDetailTarget * qty;
    for (final extra in _extraSizes) {
      final extraQty = extra.quantity <= 0 ? 1 : extra.quantity;
      sum += extra.resolvedDetailTarget * extraQty;
    }
    return sum;
  }

  List<SizeQuoteLine> _looseLines() => _lines
      .where((line) => !line.isProduct && !sizeQuoteLineIsDetail(line))
      .toList();

  List<SizeQuoteLine> _extraSizeLines() => [
    for (final extra in _extraSizes)
      ...extra.toLines(modelName: _seed.modelName, detail: _detail),
  ];

  bool _lineIsExtraSize(SizeQuoteLine line) {
    if (!line.isProduct && !sizeQuoteLineIsDetail(line)) return false;
    for (final extra in _extraSizes) {
      if (extra.owns(line)) return true;
    }
    return false;
  }

  List<SizeQuoteLine> _syncedLines() {
    final loose = _looseLines();
    if (_seed.isEmpty) return loose;
    final extras = _extraSizeLines();
    if (_detail) {
      return [
        ...sizeQuoteDetailLines(
          seed: _seed,
          quantity: _qty <= 0 ? 1 : _qty,
          targetUnit: _resolvedDetailTarget,
          sensor: _parsedMoney(_sensorCtrl),
          install: _parsedMoney(_installCtrl),
          transport: _parsedMoney(_transportCtrl),
        ),
        ...extras,
        ...loose.where(sizeQuoteLineIsExtra),
      ];
    }
    return [
      ...sizeQuoteSyncProductLine(
        lines: loose,
        seed: _seed,
        quantity: _qty,
        markupType: _markupType,
        markupValue: _markupValue,
        markupPercent: _markupPercent,
        markupAmount: _markupAmount,
      ),
      ...extras,
    ];
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
      builder: (ctx) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(inputDecorationTheme: sizeQuoteInputTheme(ctx)),
        child: _SizeQuoteLineSheet(kind: kind),
      ),
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
      builder: (ctx) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(inputDecorationTheme: sizeQuoteInputTheme(ctx)),
        child: _SizeQuoteLineSheet(existing: current[index]),
      ),
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
    HapticFeedback.selectionClick();
    final removed = current[index];
    setState(() {
      final next = [...current]..removeAt(index);
      _lines = next;
    });
    // 잘못 눌러도 바로 되돌릴 수 있게.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('「${removed.name}」을 뺐습니다.'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                final now = _syncedLines();
                final at = index.clamp(0, now.length);
                _lines = [...now]..insert(at, removed);
              });
            },
          ),
        ),
      );
  }

  void _fitTarget() {
    final target = _targetValue;
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('목표 총액을 입력해 주세요.')));
      return;
    }
    final fitted = sizeQuoteFitToTarget(_draft(), target);
    setState(() {
      _lines = fitted.lines;
      _targetCtrl.text = _won.format(target);
    });
  }

  Future<void> _save({bool send = false}) async {
    _commitPendingTarget();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('고객명을 입력해 주세요.')));
      return;
    }
    try {
      final staff = _staffName();
      final stored = await _repo.upsert(
        _draft(userName: staff),
        editorName: staff,
      );
      _leaving = true;
      unawaited(
        SizeQuoteDraftStore.open().then((store) => store.remove(stored.id)),
      );
      if (!mounted) return;
      if (!send) {
        Navigator.of(context).pop(SizeQuoteEditorResult(stored));
        return;
      }
      final action = await showSizeQuoteExportSheet(context, doc: stored);
      if (!mounted) return;
      if (action == SizeQuoteViewAction.edit) return;
      Navigator.of(
        context,
      ).pop(SizeQuoteEditorResult(stored, openExport: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  /// 닫을 때 바뀌었는지 볼 내용. 견적번호·작성자처럼 저절로 바뀌는 것은 뺀다.
  String _signature() => jsonEncode([
    _nameCtrl.text.trim(),
    _phoneCtrl.text.trim(),
    _emailCtrl.text.trim(),
    _siteCtrl.text.trim(),
    _addressCtrl.text.trim(),
    _workCtrl.text.trim(),
    _noteCtrl.text.trim(),
    _ymd,
    _seed.modelId,
    _targetCtrl.text.trim(),
    _promoIds,
    [for (final line in _syncedLines()) line.toJson()],
  ]);

  bool get _dirty => !_leaving && _signature() != _openingSignature;

  Future<void> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하지 않고 닫을까요?'),
        content: const Text(
          '임시저장하면 견적서 목록 맨 위 「작성 중」에서 이어 쓸 수 있습니다. 이 기기에만 남습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('버리고 닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'draft'),
            child: const Text('임시저장'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'draft') {
      final store = await SizeQuoteDraftStore.open();
      await store.put(
        SizeQuoteDraft(
          doc: _draft(),
          savedAt: DateTime.now().toIso8601String(),
          isNew: widget.existing == null || widget.resumingNewDraft,
        ),
      );
      if (!mounted) return;
    }
    _leaving = true;
    Navigator.of(context).pop();
  }

  /// 견적서에 제품을 넣는다. 아직 제품이 없으면 대표 제품이 되고,
  /// 있으면 본체 줄로 하나 더 붙는다(셔터는 부자재까지 합친 1SET).
  Future<void> _pickProduct() async {
    final first = _seed.isEmpty;
    final pick = await showQuoteProductPicker(
      context,
      allowManual: false,
      title: first ? '견적서에 넣을 제품' : '다른 제품 추가',
    );
    if (!mounted || pick == null || pick.isManual) return;
    if (first) {
      _applyPrimaryProduct(pick);
      return;
    }
    setState(() => _lines = [..._lines, ...sizeQuoteAddedProductLines(pick)]);
    _syncProduct();
  }

  void _applyPrimaryProduct(SizeQuoteProductPick pick) {
    final seed = pick.seed;
    final qty = pick.quantity <= 0 ? 1 : pick.quantity;
    setState(() {
      _seed = seed;
      _modelCells = null;
      _extraSizes.clear();
      _similar = const [];
      _detail = false;
      _qtyCtrl.text = '$qty';
      _markupPercentCtrl.clear();
      _markupAmountCtrl.clear();
      if (_workCtrl.text.trim().isEmpty) {
        _workCtrl.text = sizeQuoteResolvedWorkName(
          workName: '',
          categoryName: seed.categoryName,
          modelName: seed.modelName,
        );
      }
      if (_noteCtrl.text.trim().isEmpty && pick.note.trim().isNotEmpty) {
        _noteCtrl.text = pick.note.trim();
      }
      _lines = [..._looseLines(), ...pick.extraLines];
    });
    _mirrorSellingToTarget();
    _syncProduct();
    unawaited(_loadPromo());
    unawaited(_loadSimilar());
  }

  Widget _emptyProductCard(ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '아직 제품이 없습니다',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '표준단가 모델이나 셔터 산출로 고르면 규격·단가가 채워집니다. 손으로 적으려면 아래 「본체 · 추가」를 쓰세요.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => unawaited(_pickProduct()),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('제품 고르기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 품목 칸에 보일 줄. 세부 견적의 본체 칸은 위 카드가 맡으므로 추가한 제품만 둔다.
  bool _showsInLineSection(SizeQuoteLine line, String kind) {
    if (line.kind != kind || _lineIsExtraSize(line)) return false;
    if (_detail && kind == kSizeQuoteKindMain) {
      return sizeQuoteLineIsExtra(line);
    }
    return true;
  }

  Future<void> _preview() async {
    _commitPendingTarget();
    HapticFeedback.selectionClick();
    final choice = await showSizeQuotePreviewSheet(context, doc: _draft());
    if (!mounted || choice == SizeQuotePreviewChoice.close) return;
    await _save(send: choice == SizeQuotePreviewChoice.send);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doc = _draft();
    final remaining = doc.remainingToTarget;
    final lineKinds = _detail
        ? <String>[
            if (doc.lines.any(
              (e) => _showsInLineSection(e, kSizeQuoteKindMain),
            ))
              kSizeQuoteKindMain,
            kSizeQuoteKindAccessory,
            kSizeQuoteKindOther,
          ]
        : kSizeQuoteKindOrder;
    final quotedUnit = _detail ? _resolvedDetailTarget : doc.sellingUnitPrice;
    final priceUnchanged = quotedUnit == _seed.standardPrice;
    final qty = _qty <= 0 ? 1 : _qty;
    return PopScope(
      // 글자만 친 경우 다시 그리지 않아 canPop이 늦을 수 있어, 닫을 때마다 직접 본다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dirty) {
          unawaited(_confirmLeave());
          return;
        }
        _leaving = true;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null || widget.resumingNewDraft
                ? '견적서 작성'
                : '견적서 수정',
          ),
          actions: [
            IconButton(
              tooltip: '미리보기',
              onPressed: () => unawaited(_preview()),
              icon: const Icon(Icons.visibility_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: '더보기',
              onSelected: (value) {
                final page = value == 'office'
                    ? const SizeQuoteOfficeScreen()
                    : const SizeQuoteNoteScreen();
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => page));
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'office', child: Text('지사 주소')),
                PopupMenuItem(value: 'note', child: Text('노트 관리')),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _writerFooter(context, doc),
        body: Theme(
          data: Theme.of(
            context,
          ).copyWith(inputDecorationTheme: sizeQuoteInputTheme(context)),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _sectionTitle('고객 · 현장'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이름, 전화, 이메일 중 하나만 적어도 명함이 있으면 나머지를 채웁니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '고객명',
                          filled: true,
                          suffixIcon: _cardSuffix(_CardLookup.name),
                        ),
                        onChanged: _onCustomerNameChanged,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '전화',
                          filled: true,
                          suffixIcon: _cardSuffix(_CardLookup.phone),
                        ),
                        onChanged: _onCustomerPhoneChanged,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '이메일',
                          filled: true,
                          suffixIcon: _cardSuffix(_CardLookup.email),
                        ),
                        onChanged: _onCustomerEmailChanged,
                      ),
                      if (_matchedCard != null) ...[
                        const SizedBox(height: 8),
                        Material(
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.contact_page_outlined,
                              color: scheme.primary,
                            ),
                            title: Text(
                              '명함에서 가져옴 · ${_matchedCard!.displayName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (_matchedCard!.company.trim().isNotEmpty)
                                  _matchedCard!.company.trim(),
                                if (_matchedCard!.email.trim().isNotEmpty)
                                  _matchedCard!.email.trim(),
                              ].join(' · '),
                            ),
                            trailing: _cardChoices.length > 1
                                ? TextButton(
                                    onPressed: () => unawaited(_repickCard()),
                                    child: const Text('다시 고르기'),
                                  )
                                : null,
                          ),
                        ),
                      ] else if (_cardChoices.length > 1) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => unawaited(_repickCard()),
                            icon: const Icon(
                              Icons.contact_page_outlined,
                              size: 18,
                            ),
                            label: const Text('명함에서 고르기'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: _siteCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '현장명',
                          filled: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _workCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '공사명',
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '주소',
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _pickYmd,
                              borderRadius: BorderRadius.circular(16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: '견적일',
                                  filled: true,
                                ),
                                child: Text(
                                  _ymd,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '견적번호',
                                filled: true,
                              ),
                              child: Text(
                                _quoteNo.trim().isEmpty ? '저장 시 자동' : _quoteNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle(_seed.isShutter ? '셔터 산출 · 금액' : '표준단가 · 금액'),
              if (_seed.isEmpty)
                _emptyProductCard(scheme)
              else
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
                          '${_seed.widthMm}×${_seed.heightMm}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        _qtyStepper(),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: false, label: Text('기본 견적')),
                              ButtonSegment(value: true, label: Text('세부 견적')),
                            ],
                            selected: {_detail},
                            onSelectionChanged: (next) {
                              if (next.isEmpty) return;
                              _setMode(next.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _targetUnitCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: '목표 단가',
                                  suffixText: '원',
                                  filled: true,
                                ),
                                onChanged: _onTargetUnitChanged,
                                onSubmitted: (_) {
                                  if (!_detail) _applyBasicTarget();
                                },
                              ),
                            ),
                            if (!_detail) ...[
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: _basicTargetPending
                                    ? _applyBasicTarget
                                    : null,
                                child: const Text('맞추기'),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _detail
                              ? '본체·센서·시공비·운반장비대 합계가 이 금액이 됩니다.'
                              : '맞추기를 누르면 판매단가가 이 금액이 됩니다.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (_basicTargetPending)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '입력한 목표 ${_won.format(_parsedMoney(_targetUnitCtrl))}원 · 맞추기 전',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        if (!_detail) ...[
                          const SizedBox(height: 8),
                          _markupLine(
                            label: '가산율',
                            value: _markupPercent == 0
                                ? '0%'
                                : '${_signedPercentText(_markupPercent)}%',
                            minusLabel: '−5%',
                            plusLabel: '+5%',
                            onMinus: () => _stepMarkupPercent(-5),
                            onPlus: () => _stepMarkupPercent(5),
                          ),
                          const SizedBox(height: 8),
                          _markupLine(
                            label: '가산 금액',
                            value: _markupAmount == 0
                                ? '0원'
                                : '${_won.format(_markupAmount)}원',
                            minusLabel: '−20만',
                            plusLabel: '+20만',
                            onMinus: () => _stepMarkupAmount(-200000),
                            onPlus: () => _stepMarkupAmount(200000),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed:
                                  _markupPercent == 0 && _markupAmount == 0
                                  ? null
                                  : _resetMarkup,
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('가산 초기화'),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            '세부 항목',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '기본값 센서 20만 · 시공비 80만 · 운반 30만. 바꾸면 본체는 나머지로 맞춰집니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '세트 수량과 같습니다. 2세트면 센서·시공비·운반장비대도 2이고 금액은 두 배입니다.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _detailRemainderRow(bodyUnit: _bodyUnit, qty: qty),
                          _detailMoneyField(
                            label: '센서',
                            controller: _sensorCtrl,
                            qty: qty,
                            onChanged: (_) => _onDetailPartChanged(_sensorCtrl),
                          ),
                          _detailMoneyField(
                            label: '시공비',
                            controller: _installCtrl,
                            qty: qty,
                            onChanged: (_) =>
                                _onDetailPartChanged(_installCtrl),
                          ),
                          _detailMoneyField(
                            label: '운반장비대',
                            controller: _transportCtrl,
                            qty: qty,
                            onChanged: (_) =>
                                _onDetailPartChanged(_transportCtrl),
                          ),
                          if (_parsedMoney(_targetUnitCtrl) < _detailExtras)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '세부 항목이 입력한 목표보다 ${_won.format(_detailExtras - _parsedMoney(_targetUnitCtrl))}원 많습니다. 견적은 세부 합계 ${_won.format(_resolvedDetailTarget)}원으로 나갑니다.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 10),
                        _priceGapBox(
                          quotedUnit: quotedUnit,
                          unchanged: priceUnchanged,
                          qty: qty,
                          markupSummary: _detail ? '' : doc.markupSummary,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (!_seed.isEmpty && !_seed.isShutter) ...[
                for (var i = 0; i < _extraSizes.length; i++) ...[
                  _extraSizeCard(i),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _addingSize
                      ? null
                      : () => unawaited(_addExtraSize()),
                  icon: _addingSize
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text('다른 사이즈 추가'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '폭과 높이를 넣으면 이 모델의 표준단가를 찾아 견적 줄로 붙입니다. 사이즈마다 수량이 따로이고, 세부 항목도 그 수량만큼 늘어납니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (!_seed.isEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => unawaited(_pickProduct()),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(_seed.isShutter ? '다른 규격·제품 추가' : '다른 제품 추가'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _seed.isShutter
                        ? '셔터를 다시 산출하거나 표준단가 모델을 골라 본체 줄로 붙입니다.'
                        : '셔터 산출이나 다른 표준단가 모델을 본체 줄로 붙입니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
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
                  label: Text('비슷한 견적 ${_similar.length}건'),
                ),
              ],
              const SizedBox(height: 16),
              for (final kind in lineKinds) ...[
                Row(
                  children: [
                    Expanded(child: _sectionTitle(sizeQuoteKindLabel(kind))),
                    FilledButton.tonalIcon(
                      onPressed: () => unawaited(_addLine(kind)),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text('${sizeQuoteKindLabel(kind)} 추가'),
                    ),
                  ],
                ),
                if (!doc.lines.any((line) => _showsInLineSection(line, kind)))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      kind == kSizeQuoteKindMain
                          ? (_seed.isEmpty
                                ? '제품을 고르거나 「추가」로 직접 적으세요.'
                                : '본체는 표준단가에서 자동으로 들어갑니다.')
                          : '${sizeQuoteKindLabel(kind)} 항목을 추가하세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final line in doc.lines.asMap().entries)
                    if (_showsInLineSection(line.value, kind))
                      _quoteLineRow(index: line.key, line: line.value),
              ],
              if (!_detail) ...[
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
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
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
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '최종 금액',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              doc.finalChangeLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: doc.finalUnchanged
                                    ? scheme.onSurfaceVariant
                                    : const Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        doc.total <= 0 ? '-' : '${_won.format(doc.total)}원',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
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
                          image.title.trim().isEmpty
                              ? '이미지'
                              : image.title.trim(),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteCtrl,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '비고',
                  helperText: '견적서에 더할 메모입니다. 공통 노트는 자동으로 붙습니다.',
                  helperMaxLines: 2,
                  filled: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _writerFooter(BuildContext context, SizeQuoteDocument doc) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) return null;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 어디를 고치든 합계가 늘 보이게 한다.
              Row(
                children: [
                  Text(
                    '합계',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.finalChangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: doc.finalUnchanged
                            ? scheme.onSurfaceVariant
                            : const Color(0xFF047857),
                      ),
                    ),
                  ),
                  Text(
                    doc.total <= 0 ? '-' : '${_won.format(doc.total)}원',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(96, 56),
                    ),
                    onPressed: () => unawaited(_save()),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('저장', maxLines: 1, softWrap: false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: () => unawaited(_save(send: true)),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('저장하고 보내기', maxLines: 1, softWrap: false),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bumpQty(int delta) {
    final next = (_qty <= 0 ? 1 : _qty) + delta;
    if (next < 1) return;
    _qtyCtrl.text = '$next';
    _syncProduct();
  }

  Widget _qtyStepper() {
    final qty = _qty <= 0 ? 1 : _qty;
    return Row(
      children: [
        const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        _stepButton(
          icon: Icons.remove_rounded,
          tooltip: '수량 줄이기',
          onPressed: qty > 1 ? () => _bumpQty(-1) : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
            onChanged: (_) => _syncProduct(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 6, right: 8),
          child: Text('SET', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        _stepButton(
          icon: Icons.add_rounded,
          tooltip: '수량 늘리기',
          onPressed: () => _bumpQty(1),
        ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: Icon(icon, size: 26),
    );
  }

  Widget _quoteLineRow({required int index, required SizeQuoteLine line}) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (line.spec.trim().isNotEmpty) line.spec.trim(),
      if (line.unit.trim().isNotEmpty) line.unit.trim(),
      '수량 ${line.qty}',
    ].join(' · ');
    final editable = !line.isProduct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: editable ? () => unawaited(_editLine(index)) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 10, editable ? 4 : 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          line.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (meta.isNotEmpty)
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        line.amount <= 0 ? '-' : '${_won.format(line.amount)}원',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (editable)
                        Text(
                          '눌러서 수정',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  if (editable) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 1,
                      height: 36,
                      color: scheme.outlineVariant,
                    ),
                    IconButton(
                      tooltip: '빼기',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => _removeLine(index),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetMarkup() {
    _markupPercentCtrl.clear();
    _markupAmountCtrl.clear();
    _mirrorSellingToTarget();
    _syncProduct();
  }

  void _stepMarkupPercent(int delta) {
    final next = sizeQuoteStepPercent(
      _markupPercent,
      delta,
      min: -100,
      max: 300,
    );
    _markupPercentCtrl.text = _signedPercentText(next);
    _mirrorSellingToTarget();
    _syncProduct();
  }

  String _signedPercentText(num value) {
    if (value == 0) return '';
    final body = value == value.roundToDouble() ? '${value.round()}' : '$value';
    return value > 0 ? '+$body' : body;
  }

  void _stepMarkupAmount(int delta) {
    final next = sizeQuoteStepAmount(
      _markupAmount,
      delta,
      min: -_seed.standardPrice,
    );
    _markupAmountCtrl.text = next == 0 ? '' : _won.format(next);
    _mirrorSellingToTarget();
    _syncProduct();
  }

  void _setMoneySilent(TextEditingController ctrl, int value) {
    _suppressMoney = true;
    ctrl.text = value <= 0 ? '' : _won.format(value);
    _suppressMoney = false;
  }

  void _formatMoneyCtrl(TextEditingController ctrl) {
    final digits = ctrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    final formatted = n == null || n <= 0 ? '' : _won.format(n);
    if (formatted == ctrl.text) return;
    _setMoneySilent(ctrl, n ?? 0);
  }

  void _mirrorSellingToTarget() {
    if (_detail) return;
    _setMoneySilent(_targetUnitCtrl, _currentSelling);
  }

  void _onTargetUnitChanged(String _) {
    if (_suppressMoney) return;
    _formatMoneyCtrl(_targetUnitCtrl);
    setState(() {});
  }

  void _commitPendingTarget() {
    if (!_basicTargetPending) return;
    final target = _parsedMoney(_targetUnitCtrl);
    final amount = target - _seed.standardPrice;
    _markupPercentCtrl.text = '';
    _markupAmountCtrl.text = amount == 0 ? '' : _won.format(amount);
    _setMoneySilent(_targetUnitCtrl, target);
    _syncProduct();
  }

  void _applyBasicTarget() {
    if (_seed.standardPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('표준단가가 없어 목표 단가를 맞출 수 없습니다.')),
      );
      return;
    }
    final target = _parsedMoney(_targetUnitCtrl);
    if (target <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('목표 단가를 입력해 주세요.')));
      return;
    }
    _commitPendingTarget();
  }

  void _scaleDetailTo(int target) {
    final sensor = _parsedMoney(_sensorCtrl);
    final install = _parsedMoney(_installCtrl);
    final transport = _parsedMoney(_transportCtrl);
    final extras = sensor + install + transport;
    if (extras <= target) return;
    final oldTarget = _parsedMoney(_targetUnitCtrl);
    final oldBody = oldTarget > extras ? oldTarget - extras : 0;
    final oldSum = oldBody + extras;
    if (oldSum <= 0 || target <= 0) {
      _setMoneySilent(_sensorCtrl, 0);
      _setMoneySilent(_installCtrl, 0);
      _setMoneySilent(_transportCtrl, 0);
      return;
    }
    final nextSensor = (sensor * target / oldSum).floor();
    final nextInstall = (install * target / oldSum).floor();
    var nextTransport = (transport * target / oldSum).floor();
    if (nextSensor + nextInstall + nextTransport > target) {
      nextTransport = target - nextSensor - nextInstall;
      if (nextTransport < 0) nextTransport = 0;
    }
    _setMoneySilent(_sensorCtrl, nextSensor);
    _setMoneySilent(_installCtrl, nextInstall);
    _setMoneySilent(_transportCtrl, nextTransport);
  }

  void _setMode(bool detail) {
    if (detail == _detail) return;
    if (detail) {
      _commitPendingTarget();
      final selling = _currentSelling;
      _scaleDetailTo(selling);
      _setMoneySilent(_targetUnitCtrl, selling);
    } else {
      final target = _resolvedDetailTarget;
      final amount = target - _seed.standardPrice;
      _markupPercentCtrl.text = '';
      _markupAmountCtrl.text = amount == 0 ? '' : _won.format(amount);
      _setMoneySilent(_targetUnitCtrl, target);
    }
    for (final extra in _extraSizes) {
      _applyExtraMode(extra, detail);
    }
    setState(() {
      _detail = detail;
      if (!detail) {
        _lines = _lines.where((e) => !sizeQuoteLineIsDetail(e)).toList();
      }
      _lines = _syncedLines();
    });
  }

  void _applyExtraMode(_ExtraSizeForm extra, bool detail) {
    if (detail) {
      var sensor = extra.money(extra.sensorCtrl);
      var install = extra.money(extra.installCtrl);
      var transport = extra.money(extra.transportCtrl);
      if (sensor + install + transport == 0) {
        sensor = kSizeQuoteDefaultSensor;
        install = kSizeQuoteDefaultInstall;
        transport = kSizeQuoteDefaultTransport;
      }
      final selling = extra.money(extra.targetCtrl);
      final scaled = sizeQuoteScaledDetailParts(
        target: selling,
        previousTarget: selling,
        sensor: sensor,
        install: install,
        transport: transport,
      );
      _setMoneySilent(extra.sensorCtrl, scaled.sensor);
      _setMoneySilent(extra.installCtrl, scaled.install);
      _setMoneySilent(extra.transportCtrl, scaled.transport);
      _setMoneySilent(extra.targetCtrl, selling);
      return;
    }
    _setMoneySilent(extra.targetCtrl, extra.resolvedDetailTarget);
  }

  void _onDetailPartChanged(TextEditingController ctrl) {
    if (_suppressMoney) return;
    _formatMoneyCtrl(ctrl);
    final target = _parsedMoney(_targetUnitCtrl);
    if (target > 0) {
      final others = _detailExtras - _parsedMoney(ctrl);
      final max = target > others ? target - others : 0;
      final typed = _parsedMoney(ctrl);
      if (typed > max) {
        _setMoneySilent(ctrl, max);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('목표 단가 안에서 나눕니다. 더 넣으려면 목표 단가를 올리세요.')),
        );
      }
    }
    setState(() {});
  }

  Widget _priceGapBox({
    required int quotedUnit,
    required bool unchanged,
    required int qty,
    required String markupSummary,
  }) {
    final standard = _seed.standardPrice;
    final delta = quotedUnit - standard;
    final scheme = Theme.of(context).colorScheme;
    final tone = unchanged ? scheme.onSurfaceVariant : const Color(0xFF047857);
    final quoteLabel = _detail ? '목표단가' : '판매단가';
    final percent = !unchanged && standard > 0
        ? sizeQuoteSignedPercent(delta / standard * 100)
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: unchanged
            ? scheme.surfaceContainerHigh
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _gapMoneyRow('표준단가', standard),
          const SizedBox(height: 4),
          _gapMoneyRow(quoteLabel, quotedUnit, strong: true),
          if (markupSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '가산 $markupSummary',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF047857),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(height: 1, color: tone.withValues(alpha: 0.28)),
          ),
          const Text(
            '표준단가 대비',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    unchanged ? '변경 없음' : sizeQuoteSignedWon(delta),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: tone,
                    ),
                  ),
                ),
              ),
              if (percent.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  percent,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: tone,
                  ),
                ),
              ],
            ],
          ),
          if (qty > 1 && delta != 0) ...[
            const SizedBox(height: 4),
            Text(
              '수량 $qty SET 합계  ${sizeQuoteSignedWon(delta * qty)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800, color: tone),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gapMoneyRow(String label, int amount, {bool strong = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(
          '${_won.format(amount)}원',
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _detailRemainderRow({required int bodyUnit, required int qty}) {
    final sets = qty <= 0 ? 1 : qty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '본체',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${_won.format(bodyUnit)}원',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (sets > 1) _qtyAmountCaption(sets, bodyUnit),
        ],
      ),
    );
  }

  Widget _qtyAmountCaption(int qty, int unitPrice) {
    final scheme = Theme.of(context).colorScheme;
    final amount = unitPrice <= 0 ? 0 : unitPrice * qty;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        amount <= 0 ? '수량 $qty' : '수량 $qty · ${_won.format(amount)}원',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _detailMoneyField({
    required String label,
    required TextEditingController controller,
    required int qty,
    required ValueChanged<String> onChanged,
  }) {
    final sets = qty <= 0 ? 1 : qty;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              SizedBox(
                width: 168,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    suffixText: '원',
                    filled: true,
                    isDense: true,
                    contentPadding: EdgeInsets.fromLTRB(8, 12, 8, 12),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          if (sets > 1) _qtyAmountCaption(sets, _parsedMoney(controller)),
        ],
      ),
    );
  }

  bool _hasSize(int widthMm, int heightMm) {
    if (widthMm == _seed.widthMm && heightMm == _seed.heightMm) return true;
    for (final extra in _extraSizes) {
      if (extra.widthMm == widthMm && extra.heightMm == heightMm) return true;
    }
    return false;
  }

  Future<List<StandardPriceCell>> _loadModelCells() async {
    final cached = _modelCells;
    if (cached != null) return cached;
    final rows = await ref
        .read(standardUnitPriceRepositoryProvider)
        .fetchPrices(_seed.modelId);
    final cells = [for (final row in rows) row.asCell];
    _modelCells = cells;
    return cells;
  }

  Future<void> _addExtraSize() async {
    if (_seed.modelId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델을 알 수 없어 사이즈를 추가할 수 없습니다.')),
      );
      return;
    }
    setState(() => _addingSize = true);
    List<StandardPriceCell> cells;
    try {
      cells = await _loadModelCells();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      return;
    } finally {
      if (mounted) setState(() => _addingSize = false);
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<_PricedSize>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _AddSizeSheet(
        modelName: _seed.modelName,
        cells: cells,
        garage: _seed.categoryName.trim() == '차고문',
        taken: _hasSize,
      ),
    );
    if (picked == null || !mounted) return;
    if (_hasSize(picked.widthMm, picked.heightMm)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 있는 사이즈입니다.')));
      return;
    }
    final scaled = sizeQuoteScaledDetailParts(
      target: picked.standardPrice,
      previousTarget: picked.standardPrice,
      sensor: kSizeQuoteDefaultSensor,
      install: kSizeQuoteDefaultInstall,
      transport: kSizeQuoteDefaultTransport,
    );
    setState(() {
      _extraSizes.add(
        _ExtraSizeForm(
          widthMm: picked.widthMm,
          heightMm: picked.heightMm,
          standardPrice: picked.standardPrice,
          quantity: 1,
          targetUnit: picked.standardPrice,
          sensor: scaled.sensor,
          install: scaled.install,
          transport: scaled.transport,
          won: _won,
        ),
      );
    });
    if (!mounted) return;
    final estimated = picked.estimated ? '추정 ' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${picked.widthMm}×${picked.heightMm} $estimated표준단가 ${_won.format(picked.standardPrice)}원을 견적 줄에 넣었습니다.',
        ),
      ),
    );
  }

  void _removeExtraSize(int index) {
    if (index < 0 || index >= _extraSizes.length) return;
    final extra = _extraSizes.removeAt(index);
    extra.dispose();
    setState(() {});
  }

  void _setExtraQty(_ExtraSizeForm extra, int next) {
    if (next < 1) return;
    extra.qtyCtrl.text = '$next';
    setState(() {});
  }

  void _onExtraMoneyChanged(
    _ExtraSizeForm extra,
    TextEditingController ctrl, {
    required bool part,
  }) {
    if (_suppressMoney) return;
    _formatMoneyCtrl(ctrl);
    if (part && _detail) {
      final target = extra.money(extra.targetCtrl);
      if (target > 0) {
        final others = extra.extras - extra.money(ctrl);
        final max = target > others ? target - others : 0;
        if (extra.money(ctrl) > max) {
          _setMoneySilent(ctrl, max);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('목표 단가 안에서 나눕니다. 더 넣으려면 목표 단가를 올리세요.'),
            ),
          );
        }
      }
    }
    setState(() {});
  }

  Widget _extraSizeCard(int index) {
    final extra = _extraSizes[index];
    final scheme = Theme.of(context).colorScheme;
    final qty = extra.quantity <= 0 ? 1 : extra.quantity;
    final selling = _detail
        ? extra.resolvedDetailTarget
        : extra.money(extra.targetCtrl);
    final delta = selling - extra.standardPrice;
    final unchanged = extra.standardPrice > 0 && delta == 0;
    final tone = unchanged ? scheme.onSurfaceVariant : const Color(0xFF047857);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_seed.modelName.trim().isEmpty ? '사이즈' : _seed.modelName.trim()}  ${extra.widthMm}×${extra.heightMm}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '이 사이즈 빼기',
                  onPressed: () => _removeExtraSize(index),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '표준단가 ${_won.format(extra.standardPrice)}원',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _boundQtyStepper(
              controller: extra.qtyCtrl,
              quantity: qty,
              onQuantity: (next) => _setExtraQty(extra, next),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: extra.targetCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _detail ? '목표 단가' : '판매 단가',
                suffixText: '원',
                filled: true,
              ),
              onChanged: (_) =>
                  _onExtraMoneyChanged(extra, extra.targetCtrl, part: false),
            ),
            if (_detail) ...[
              const SizedBox(height: 8),
              _detailRemainderRow(bodyUnit: extra.bodyUnit, qty: qty),
              _detailMoneyField(
                label: '센서',
                controller: extra.sensorCtrl,
                qty: qty,
                onChanged: (_) =>
                    _onExtraMoneyChanged(extra, extra.sensorCtrl, part: true),
              ),
              _detailMoneyField(
                label: '시공비',
                controller: extra.installCtrl,
                qty: qty,
                onChanged: (_) =>
                    _onExtraMoneyChanged(extra, extra.installCtrl, part: true),
              ),
              _detailMoneyField(
                label: '운반장비대',
                controller: extra.transportCtrl,
                qty: qty,
                onChanged: (_) => _onExtraMoneyChanged(
                  extra,
                  extra.transportCtrl,
                  part: true,
                ),
              ),
              if (extra.money(extra.targetCtrl) < extra.extras)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '세부 항목이 목표보다 ${_won.format(extra.extras - extra.money(extra.targetCtrl))}원 많습니다. 이 사이즈는 ${_won.format(extra.resolvedDetailTarget)}원으로 나갑니다.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              unchanged
                  ? '표준단가와 같습니다'
                  : '표준단가 대비 ${sizeQuoteSignedWon(delta)}${qty > 1 && delta != 0 ? ' · ${qty}SET ${sizeQuoteSignedWon(delta * qty)}' : ''}',
              style: TextStyle(fontWeight: FontWeight.w800, color: tone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundQtyStepper({
    required TextEditingController controller,
    required int quantity,
    required ValueChanged<int> onQuantity,
  }) {
    return Row(
      children: [
        const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        _stepButton(
          icon: Icons.remove_rounded,
          tooltip: '수량 줄이기',
          onPressed: quantity > 1 ? () => onQuantity(quantity - 1) : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 6, right: 8),
          child: Text('SET', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        _stepButton(
          icon: Icons.add_rounded,
          tooltip: '수량 늘리기',
          onPressed: () => onQuantity(quantity + 1),
        ),
      ],
    );
  }

  Widget _markupLine({
    required String label,
    required String value,
    required String minusLabel,
    required String plusLabel,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    const buttonStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
      minimumSize: WidgetStatePropertyAll(Size(0, 36)),
    );
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 4),
        OutlinedButton(
          style: buttonStyle,
          onPressed: onMinus,
          child: Text(minusLabel),
        ),
        const SizedBox(width: 4),
        OutlinedButton(
          style: buttonStyle,
          onPressed: onPlus,
          child: Text(plusLabel),
        ),
      ],
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
    final price = int.tryParse(
      _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
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
            final sheetH =
                constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : ((size.height - keyboard - pad.bottom) * 0.9).clamp(
                    280.0,
                    size.height,
                  );
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
                              final digits = v.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
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
                        child: Text(widget.existing == null ? '추가' : '저장'),
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

class _PricedSize {
  const _PricedSize({
    required this.widthMm,
    required this.heightMm,
    required this.standardPrice,
    required this.estimated,
  });

  final int widthMm;
  final int heightMm;
  final int standardPrice;
  final bool estimated;
}

class _AddSizeSheet extends StatefulWidget {
  const _AddSizeSheet({
    required this.modelName,
    required this.cells,
    required this.garage,
    required this.taken,
  });

  final String modelName;
  final List<StandardPriceCell> cells;
  final bool garage;
  final bool Function(int widthMm, int heightMm) taken;

  @override
  State<_AddSizeSheet> createState() => _AddSizeSheetState();
}

class _AddSizeSheetState extends State<_AddSizeSheet> {
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _won = NumberFormat('#,###');

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  int _mm(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  void _setMm(TextEditingController ctrl, int mm) {
    ctrl.text = '$mm';
    setState(() {});
  }

  StandardPriceInference? get _inference {
    final width = _mm(_widthCtrl);
    final height = _mm(_heightCtrl);
    if (width <= 0 || height <= 0) return null;
    return inferStandardPrice(
      cells: widget.cells,
      widthMm: width,
      heightMm: height,
      ceilingHeights: widget.garage,
    );
  }

  bool _unavailable(StandardPriceInference inference, int price) {
    return inference.outOfRange ||
        (!inference.isEstimated &&
            inference.match?.available == false &&
            (inference.isExactBucket || price <= 0));
  }

  void _submit(int width, int height, int price, bool estimated) {
    if (widget.taken(width, height)) return;
    Navigator.pop(
      context,
      _PricedSize(
        widthMm: width,
        heightMm: height,
        standardPrice: price,
        estimated: estimated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = _mm(_widthCtrl);
    final height = _mm(_heightCtrl);
    final inference = _inference;
    final price = inference?.estimatedPrice ?? 0;
    final blocked = inference != null && _unavailable(inference, price);
    final duplicate = width > 0 && height > 0 && widget.taken(width, height);
    final canAdd = inference != null && !blocked && price > 0 && !duplicate;
    final heights = widget.garage ? garageQuickHeights : standardQuickHeights;
    final model = widget.modelName.trim().isEmpty
        ? '이 모델'
        : widget.modelName.trim();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    String status;
    Color statusColor;
    if (width <= 0 || height <= 0) {
      status = '폭과 높이를 넣으면 $model 표준단가를 찾습니다.';
      statusColor = scheme.onSurfaceVariant;
    } else if (duplicate) {
      status = '이미 견적에 있는 사이즈입니다.';
      statusColor = const Color(0xFFDC2626);
    } else if (inference != null && inference.outOfRange) {
      status = '이 폭·높이는 표준단가 범위 밖입니다.';
      statusColor = const Color(0xFFDC2626);
    } else if (blocked || price <= 0) {
      status = blocked ? '해당 사이즈는 표준단가에서 불가입니다.' : '이 사이즈의 표준단가를 찾지 못했습니다.';
      statusColor = const Color(0xFFDC2626);
    } else {
      final estimated = inference!.isEstimated ? '추정 ' : '';
      status = '$estimated표준단가 ${_won.format(price)}원';
      statusColor = inference.isEstimated
          ? const Color(0xFFB45309)
          : const Color(0xFF047857);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$model 다른 사이즈',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '표준단가에서 온 이 모델의 폭·높이를 넣으면 단가를 찾아 견적 줄에 붙입니다.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _widthCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '폭 (mm)',
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _mmChips(
                label: '폭',
                values: standardQuickWidths,
                selected: width,
                color: const Color(0xFF1D4ED8),
                onPick: (mm) => _setMm(_widthCtrl, mm),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '높이 (mm)',
                  filled: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canAdd) {
                    _submit(width, height, price, inference.isEstimated);
                  }
                },
              ),
              const SizedBox(height: 8),
              _mmChips(
                label: '높이',
                values: heights,
                selected: height,
                color: const Color(0xFF0F766E),
                onPick: (mm) => _setMm(_heightCtrl, mm),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: canAdd
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: canAdd
                    ? () => _submit(width, height, price, inference.isEstimated)
                    : null,
                child: const Text('이 단가로 추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mmChips({
    required String label,
    required List<int> values,
    required int selected,
    required Color color,
    required ValueChanged<int> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final mm = values[index];
              final text = mm == 2150
                  ? '2150 4단'
                  : mm == 2700
                  ? '2700 5단'
                  : '$mm';
              return ChoiceChip(
                label: Text(text),
                selected: selected == mm,
                onSelected: (_) => onPick(mm),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExtraSizeForm {
  _ExtraSizeForm({
    required this.widthMm,
    required this.heightMm,
    required this.standardPrice,
    required int quantity,
    required int targetUnit,
    required int sensor,
    required int install,
    required int transport,
    required NumberFormat won,
  }) : qtyCtrl = TextEditingController(text: '${quantity <= 0 ? 1 : quantity}'),
       targetCtrl = TextEditingController(
         text: targetUnit <= 0 ? '' : won.format(targetUnit),
       ),
       sensorCtrl = TextEditingController(
         text: sensor <= 0 ? '' : won.format(sensor),
       ),
       installCtrl = TextEditingController(
         text: install <= 0 ? '' : won.format(install),
       ),
       transportCtrl = TextEditingController(
         text: transport <= 0 ? '' : won.format(transport),
       );

  factory _ExtraSizeForm.fromGroup(SizeQuoteSizeGroup group, NumberFormat won) {
    return _ExtraSizeForm(
      widthMm: group.widthMm,
      heightMm: group.heightMm,
      standardPrice: group.standardPrice,
      quantity: group.quantity,
      targetUnit: group.sellingUnit,
      sensor: group.sensor,
      install: group.install,
      transport: group.transport,
      won: won,
    );
  }

  final int widthMm;
  final int heightMm;
  final int standardPrice;
  final TextEditingController qtyCtrl;
  final TextEditingController targetCtrl;
  final TextEditingController sensorCtrl;
  final TextEditingController installCtrl;
  final TextEditingController transportCtrl;

  int get quantity =>
      int.tryParse(qtyCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 1;

  int money(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get extras =>
      money(sensorCtrl) + money(installCtrl) + money(transportCtrl);

  int get resolvedDetailTarget {
    final typed = money(targetCtrl);
    final parts = extras;
    if (typed < parts) return parts;
    return typed;
  }

  int get bodyUnit {
    final body = resolvedDetailTarget - extras;
    return body < 0 ? 0 : body;
  }

  bool owns(SizeQuoteLine line) {
    if (line.widthMm == widthMm && line.heightMm == heightMm && widthMm > 0) {
      return true;
    }
    return line.spec.trim() == '$widthMm×$heightMm';
  }

  List<SizeQuoteLine> toLines({
    required String modelName,
    required bool detail,
  }) {
    return sizeQuoteSizeLines(
      modelName: modelName,
      widthMm: widthMm,
      heightMm: heightMm,
      quantity: quantity,
      standardPrice: standardPrice,
      detail: detail,
      unitPrice: detail ? resolvedDetailTarget : money(targetCtrl),
      sensor: money(sensorCtrl),
      install: money(installCtrl),
      transport: money(transportCtrl),
    );
  }

  void dispose() {
    qtyCtrl.dispose();
    targetCtrl.dispose();
    sensorCtrl.dispose();
    installCtrl.dispose();
    transportCtrl.dispose();
  }
}

/// 견적서 입력칸: 테두리와 바탕을 보여 어디를 눌러 적는지 바로 보이게 한다.
InputDecorationThemeData sizeQuoteInputTheme(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );
  return Theme.of(context).inputDecorationTheme.copyWith(
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(scheme.outlineVariant, 1.2),
    enabledBorder: border(scheme.outlineVariant, 1.2),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error, 1.4),
    focusedErrorBorder: border(scheme.error, 2),
    labelStyle: TextStyle(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: TextStyle(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
    ),
  );
}
