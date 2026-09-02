import 'dart:async';

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_photo.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 접수·팔로우업 중 단가 조회. 상담 창을 닫지 않는다.
Future<SupportUnitPriceItem?> showSupportUnitPriceLookupSheet(
  BuildContext context, {
  ValueChanged<SupportUnitPriceItem>? onInsert,
  String insertLabel = '넣기',
  bool closeOnInsert = true,
  int Function()? quoteTotal,
  VoidCallback? onOpenManage,
}) {
  return showModalBottomSheet<SupportUnitPriceItem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SupportUnitPriceLookupSheet(
      onInsert: onInsert,
      insertLabel: insertLabel,
      closeOnInsert: closeOnInsert,
      quoteTotal: quoteTotal,
      onOpenManage: onOpenManage,
    ),
  );
}

class _SupportUnitPriceLookupSheet extends ConsumerStatefulWidget {
  const _SupportUnitPriceLookupSheet({
    this.onInsert,
    this.insertLabel = '넣기',
    this.closeOnInsert = true,
    this.quoteTotal,
    this.onOpenManage,
  });

  final ValueChanged<SupportUnitPriceItem>? onInsert;
  final String insertLabel;
  final bool closeOnInsert;
  final int Function()? quoteTotal;
  final VoidCallback? onOpenManage;

  @override
  ConsumerState<_SupportUnitPriceLookupSheet> createState() =>
      _SupportUnitPriceLookupSheetState();
}

class _SupportUnitPriceLookupSheetState
    extends ConsumerState<_SupportUnitPriceLookupSheet> {
  final _queryCtrl = TextEditingController();
  List<SupportUnitPriceItem> _items = const [];
  String _query = '';
  String _filter = kSupportUnitPriceFilterAll;
  bool _loading = true;
  Object? _error;
  final _won = NumberFormat('#,###');
  final List<String> _addedNames = [];
  int _addedAmount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportUnitPriceItem> get _visible {
    return _items
        .where((e) => supportUnitPriceInFilter(e, _filter))
        .where((e) => supportUnitPriceMatches(e, _query))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(supportUnitPriceRepositoryProvider).list();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  bool get _canInsert => widget.onInsert != null;

  Future<void> _insert(SupportUnitPriceItem item) async {
    widget.onInsert?.call(item);
    if (widget.closeOnInsert) {
      Navigator.pop(context, item);
      return;
    }
    if (!mounted) return;
    final lineAmount = item.price ?? 0;
    setState(() {
      _addedNames.add(item.name);
      _addedAmount += lineAmount;
    });
    final price = lineAmount <= 0 ? '-' : '${_won.format(lineAmount)}원';
    final total = widget.quoteTotal?.call() ?? _addedAmount;
    final totalLabel = total <= 0 ? '-' : '${_won.format(total)}원';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
        title: const Text('견적에 넣었습니다'),
        content: Text(
          '${item.name}\n$price\n\n이번에 ${_addedNames.length}건\n합계 $totalLabel',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showItem(SupportUnitPriceItem item) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewPadding.top - 56)
        .clamp(160.0, media.size.height * 0.7);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SupportUnitPricePhoto(
                      url: item.primaryImageUrl,
                      width: 72,
                      height: 72,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supportUnitPriceFamily(item.productLine),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          Text(
                            supportUnitPriceGroupCategory(item),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            supportUnitPriceRowTitle(item),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (item.unit.trim().isNotEmpty)
                  Text(
                    '단위 ${item.unit.trim()}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                Text(
                  item.price == null ? '-' : '${_won.format(item.price)}원',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                if (item.displayCompetitorPrice != null)
                  Text(
                    formatSupportUnitPriceCompetitor(
                      item.displayCompetitorPrice,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (item.displayNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(item.displayNote),
                ],
                if (_canInsert) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _insert(item);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(widget.insertLabel),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final media = MediaQuery.of(context);
    final height =
        (media.size.height -
                media.viewPadding.top -
                media.viewInsets.bottom -
                56)
            .clamp(200.0, media.size.height * 0.72);
    final rows = _visible;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'A/S 단가 조회',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (widget.onOpenManage != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenManage!();
                      },
                      child: const Text('단가표 관리'),
                    ),
                ],
              ),
            ),
            if (_canInsert)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  '오른쪽 「${widget.insertLabel}」를 누르면 견적에 들어갑니다. 여러 개를 이어서 넣을 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_addedNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Text(
                      '견적에 ${_addedNames.length}건 넣음 · 합계 ${_won.format(widget.quoteTotal?.call() ?? _addedAmount)}원 · 방금 ${_addedNames.last}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: TextField(
                controller: _queryCtrl,
                decoration: const InputDecoration(
                  hintText: '품명 · 분류 · 금액 검색',
                  prefixIcon: Icon(Icons.search_rounded),
                  filled: true,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: kSupportUnitPriceFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final tab = kSupportUnitPriceFilters[i];
                  final selected = _filter == tab;
                  return Material(
                    color: selected ? accent : accent.withValues(alpha: 0.14),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => _filter = tab),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const AppLoading(message: '단가표를 불러오는 중…')
                  : _error != null
                  ? AppEmpty(
                      icon: Icons.cloud_off_outlined,
                      message: '단가표를 불러오지 못했습니다.',
                      detail: koreanErrorMessage(_error!),
                      actionLabel: '다시 시도',
                      onAction: () => unawaited(_reload()),
                    )
                  : rows.isEmpty
                  ? AppEmpty(
                      icon: Icons.search_off_rounded,
                      message: _query.trim().isEmpty
                          ? '단가가 없습니다.'
                          : '검색 결과가 없습니다.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final item = rows[i];
                        final line = supportUnitPriceFamily(item.productLine);
                        final cat = supportUnitPriceGroupCategory(item);
                        final prev = i == 0 ? null : rows[i - 1];
                        final showLine =
                            prev == null ||
                            supportUnitPriceFamily(prev.productLine) != line;
                        final showCat =
                            showLine ||
                            supportUnitPriceGroupCategory(prev) != cat;
                        final subtitle = supportUnitPriceListSubtitle(item);
                        final title = supportUnitPriceRowTitle(item);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showLine)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  4,
                                  i == 0 ? 4 : 12,
                                  4,
                                  2,
                                ),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                  ),
                                ),
                              ),
                            if (showCat)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  6,
                                  4,
                                  0,
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppTokens.info(scheme),
                                  ),
                                ),
                              ),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: SearchHighlightText(
                                text: title,
                                query: _query,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: SearchHighlightText(
                                text: [
                                  if (item.price != null)
                                    '${_won.format(item.price)}원',
                                  if (subtitle.isNotEmpty) subtitle,
                                ].join(' · '),
                                query: _query,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: _canInsert
                                  ? FilledButton(
                                      onPressed: () => _insert(item),
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(widget.insertLabel),
                                    )
                                  : SearchHighlightText(
                                      text: item.price == null
                                          ? '-'
                                          : '${_won.format(item.price)}원',
                                      query: _query,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                      ),
                                    ),
                              onTap: () => _showItem(item),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
