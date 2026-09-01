import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_lookup_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_photo.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_sections_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_formatters.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/image_source_sheet.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

Future<void> openSupportUnitPriceScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const SupportUnitPriceScreen()),
  );
}

Future<SupportUnitPriceItem?> openSupportUnitPriceLookup(
  BuildContext context, {
  ValueChanged<SupportUnitPriceItem>? onInsert,
  String insertLabel = '넣기',
}) {
  return showSupportUnitPriceLookupSheet(
    context,
    onInsert: onInsert,
    insertLabel: insertLabel,
    onOpenManage: () => openSupportUnitPriceScreen(context),
  );
}

/// 접수·팔로우업 화면에서 단가표를 바로 연다.
class SupportUnitPriceOpenTile extends StatelessWidget {
  const SupportUnitPriceOpenTile({
    super.key,
    this.subtitle = '품명 · 금액 검색',
    this.onInsert,
    this.insertLabel = '넣기',
  });

  final String subtitle;
  final ValueChanged<SupportUnitPriceItem>? onInsert;
  final String insertLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showSupportUnitPriceLookupSheet(
          context,
          onInsert: onInsert,
          insertLabel: insertLabel,
          onOpenManage: () => openSupportUnitPriceScreen(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.grid_on_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A/S 단가표',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A/S 견적단가표. 사이즈 표준단가와 별개이며, 접수·팔로우업 중 검색·수정한다.
class SupportUnitPriceScreen extends ConsumerStatefulWidget {
  const SupportUnitPriceScreen({super.key});

  @override
  ConsumerState<SupportUnitPriceScreen> createState() =>
      _SupportUnitPriceScreenState();
}

class _SupportUnitPriceScreenState
    extends ConsumerState<SupportUnitPriceScreen> {
  final _queryCtrl = TextEditingController();
  List<SupportUnitPriceItem> _items = const [];
  List<SupportUnitPriceSection> _sections = const [];
  String _query = '';
  String _filter = kSupportUnitPriceFilterAll;
  bool _loading = true;
  bool _busy = false;
  Object? _error;
  final _won = NumberFormat('#,###');

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

  (String, String) _actor() {
    final user = ref.read(authControllerProvider);
    return (user?.id ?? '', (user?.name ?? '').trim());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(supportUnitPriceRepositoryProvider);
      final actor = _actor();
      await repo.migrateLocalIfNeeded(
        ref.read(appDependenciesProvider).prefs,
        userId: actor.$1,
        userName: actor.$2.isEmpty ? '알 수 없음' : actor.$2,
      );
      final items = await repo.list();
      final sections = await repo.listSections();
      if (!mounted) return;
      setState(() {
        _items = items;
        _sections = sections;
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

  Future<void> _edit({SupportUnitPriceItem? existing}) async {
    if (_busy) return;
    final saved = await showModalBottomSheet<_UnitPriceEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _SupportUnitPriceEditor(
        existing: existing,
        productLines: kSupportUnitPriceFamilies,
        categoriesByLine: {
          for (final family in kSupportUnitPriceFamilies)
            family: [
              ...{
                for (final item in _items)
                  if (!item.isLabor &&
                      supportUnitPriceFamily(item.productLine) == family &&
                      item.category.trim().isNotEmpty)
                    item.category.trim(),
              },
            ]..sort(),
        },
        laborWorkTypes: supportUnitPriceLaborWorkTypes(_items),
        laborSpecsByWork: {
          for (final work in supportUnitPriceLaborWorkTypes(_items))
            work: supportUnitPriceLaborSpecs(_items, workType: work),
        },
      ),
    );
    if (saved == null || !mounted) return;
    if (saved.delete && existing != null) {
      await _delete(existing, confirmed: true);
      return;
    }
    final item = saved.item;
    if (item == null) return;
    final actor = _actor();
    final userName = actor.$2.isEmpty ? '알 수 없음' : actor.$2;
    setState(() => _busy = true);
    try {
      final repo = ref.read(supportUnitPriceRepositoryProvider);
      late SupportUnitPriceItem persisted;
      if (existing == null || item.id.isEmpty) {
        persisted = await repo.create(
          name: item.name,
          spec: item.spec,
          price: item.price,
          competitorPrice: item.competitorPrice,
          note: item.note,
          productLine: item.productLine,
          category: item.category,
          nameEn: item.nameEn,
          unit: item.unit,
          kind: item.kind,
          imageUrl: item.imageUrl,
          diagramUrl: item.diagramUrl,
          userId: actor.$1,
          userName: userName,
        );
      } else {
        persisted = await repo.update(
          existing: existing,
          name: item.name,
          spec: item.spec,
          price: item.price,
          competitorPrice: item.competitorPrice,
          note: item.note,
          productLine: item.productLine,
          category: item.category,
          nameEn: item.nameEn,
          unit: item.unit,
          kind: item.kind,
          imageUrl: item.imageUrl,
          diagramUrl: item.diagramUrl,
          userId: actor.$1,
          userName: userName,
        );
      }
      final localPath = saved.pendingImagePath;
      if (localPath != null && localPath.trim().isNotEmpty) {
        final url = await ref
            .read(b2UploadRepositoryProvider)
            .uploadSupportCallFile(filePath: localPath);
        await repo.update(
          existing: persisted,
          name: persisted.name,
          spec: persisted.spec,
          price: persisted.price,
          competitorPrice: persisted.competitorPrice,
          note: persisted.note,
          productLine: persisted.productLine,
          category: persisted.category,
          nameEn: persisted.nameEn,
          unit: persisted.unit,
          kind: persisted.kind,
          imageUrl: url,
          diagramUrl: persisted.diagramUrl,
          userId: actor.$1,
          userName: userName,
        );
      }
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

  Future<void> _delete(
    SupportUnitPriceItem item, {
    bool confirmed = false,
  }) async {
    if (_busy) return;
    final ok = confirmed
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('단가 삭제'),
              content: Text('${item.name}을(를) 삭제할까요?\n삭제해도 변경 이력은 남습니다.'),
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
    final actor = _actor();
    setState(() => _busy = true);
    try {
      await ref
          .read(supportUnitPriceRepositoryProvider)
          .delete(
            item: item,
            userId: actor.$1,
            userName: actor.$2.isEmpty ? '알 수 없음' : actor.$2,
          );
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

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SupportUnitPriceHistoryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/S 단가표'),
        actions: [
          IconButton(
            tooltip: '분류 관리',
            onPressed: _busy
                ? null
                : () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SupportUnitPriceSectionsScreen(
                          items: _items,
                          sections: _sections,
                        ),
                      ),
                    );
                    if (mounted) unawaited(_reload());
                  },
            icon: const Icon(Icons.account_tree_outlined),
          ),
          IconButton(
            tooltip: '변경 이력',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: '단가 추가',
            onPressed: _busy ? null : () => _edit(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('단가 입력'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '품명 · 분류 · 금액 검색',
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
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: kSupportUnitPriceFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final tab = kSupportUnitPriceFilters[i];
                final selectedChip = _filter == tab;
                final count = tab == kSupportUnitPriceFilterAll
                    ? _items
                          .where((e) => supportUnitPriceMatches(e, _query))
                          .length
                    : _items
                          .where((e) => supportUnitPriceInFilter(e, tab))
                          .where((e) => supportUnitPriceMatches(e, _query))
                          .length;
                return Material(
                  color: selectedChip ? accent : accent.withValues(alpha: 0.14),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: accent.withValues(alpha: selectedChip ? 0 : 0.45),
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => setState(() => _filter = tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          tab == kSupportUnitPriceFilterAll
                              ? tab
                              : '$tab $count',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: selectedChip ? Colors.white : accent,
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
                ? const AppLoading(message: 'A/S 단가표를 불러오는 중…')
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
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
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
                                  i == 0 ? 4 : 16,
                                  4,
                                  2,
                                ),
                                child: SearchHighlightText(
                                  text: line,
                                  query: _query,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                  ),
                                ),
                              ),
                            if (showCat)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  4,
                                  8,
                                  4,
                                  2,
                                ),
                                child: SearchHighlightText(
                                  text: cat,
                                  query: _query,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppTokens.info(scheme),
                                  ),
                                ),
                              ),
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.fromLTRB(
                                8,
                                0,
                                4,
                                0,
                              ),
                              title: SearchHighlightText(
                                text: title,
                                query: _query,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: subtitle.isEmpty
                                  ? null
                                  : SearchHighlightText(
                                      text: subtitle,
                                      query: _query,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: SearchHighlightText(
                                text: item.price == null
                                    ? '-'
                                    : '${_won.format(item.price)}원',
                                query: _query,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: accent,
                                ),
                              ),
                              onTap: _busy
                                  ? null
                                  : () => _edit(existing: item),
                              onLongPress: _busy
                                  ? null
                                  : () => _delete(item),
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

class SupportUnitPriceHistoryScreen extends ConsumerStatefulWidget {
  const SupportUnitPriceHistoryScreen({
    super.key,
    this.itemId,
    this.itemName,
  });

  final String? itemId;
  final String? itemName;

  @override
  ConsumerState<SupportUnitPriceHistoryScreen> createState() =>
      _SupportUnitPriceHistoryScreenState();
}

class _SupportUnitPriceHistoryScreenState
    extends ConsumerState<SupportUnitPriceHistoryScreen> {
  final _queryCtrl = TextEditingController();
  List<SupportUnitPriceChangeLog> _logs = const [];
  String _query = '';
  bool _loading = true;
  Object? _error;

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

  bool get _itemScoped {
    final id = widget.itemId?.trim() ?? '';
    final name = widget.itemName?.trim() ?? '';
    return id.isNotEmpty || name.isNotEmpty;
  }

  List<SupportUnitPriceChangeLog> get _visible {
    return _logs
        .where((e) => supportUnitPriceChangeLogMatches(e, _query))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final itemId = widget.itemId?.trim() ?? '';
      var logs = await ref
          .read(supportUnitPriceRepositoryProvider)
          .listChangeLogs(itemId: itemId.isEmpty ? null : itemId);
      final name = widget.itemName?.trim() ?? '';
      if (itemId.isEmpty && name.isNotEmpty) {
        logs = logs.where((e) => e.itemName.trim() == name).toList();
      }
      if (!mounted) return;
      setState(() {
        _logs = logs;
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

  void _openItemHistory(SupportUnitPriceChangeLog log) {
    final itemId = (log.itemId ?? '').trim();
    final itemName = supportUnitPriceChangeLogTitle(log);
    if (itemId.isEmpty && itemName.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportUnitPriceHistoryScreen(
          itemId: itemId.isEmpty ? null : itemId,
          itemName: itemName.isEmpty ? null : itemName,
        ),
      ),
    );
  }

  void _showDetail(SupportUnitPriceChangeLog log) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _SupportUnitPriceChangeDetail(
        log: log,
        showItemHistory: !_itemScoped,
        onOpenItemHistory: () {
          Navigator.pop(ctx);
          if (!mounted) return;
          _openItemHistory(log);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _visible;
    final itemTitle = widget.itemName?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          itemTitle.isEmpty ? 'A/S 단가 변경 이력' : '$itemTitle 이력',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '누가 · 품명 · 어떻게 바꿨는지 검색',
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
            child: _loading
                ? const AppLoading(message: '이력을 불러오는 중…')
                : _error != null
                ? AppEmpty(
                    icon: Icons.cloud_off_outlined,
                    message: '이력을 불러오지 못했습니다.',
                    detail: koreanErrorMessage(_error!),
                    actionLabel: '다시 시도',
                    onAction: () => unawaited(_reload()),
                  )
                : rows.isEmpty
                ? AppEmpty(
                    icon: Icons.history_rounded,
                    message: _query.trim().isEmpty
                        ? (_itemScoped
                              ? '이 부품의 변경 이력이 없습니다.'
                              : '아직 단가 변경 이력이 없습니다.')
                        : '검색 결과가 없습니다.',
                    detail: _query.trim().isEmpty
                        ? (_itemScoped
                              ? null
                              : '단가를 추가·수정·삭제하면 누가 어떻게 바꿨는지 남습니다.')
                        : null,
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final log = rows[i];
                        final title = supportUnitPriceChangeLogTitle(log);
                        final priceLine = supportUnitPriceChangeLogPriceLine(
                          log,
                        );
                        final meta = [
                          supportUnitPriceActionLabel(log.action),
                          log.userName.trim().isEmpty
                              ? '알 수 없음'
                              : log.userName.trim(),
                          formatSeoulDateTimeDots(log.createdAt),
                        ].join(' · ');
                        return Material(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.42,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showDetail(log),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: switch (log.action) {
                                      'create' => AppTokens.success(
                                        scheme,
                                      ).withValues(alpha: 0.18),
                                      'delete' => scheme.errorContainer,
                                      _ => scheme.primaryContainer,
                                    },
                                    child: Icon(
                                      switch (log.action) {
                                        'create' => Icons.add_rounded,
                                        'delete' =>
                                          Icons.delete_outline_rounded,
                                        _ => Icons.edit_outlined,
                                      },
                                      color: switch (log.action) {
                                        'create' => AppTokens.success(scheme),
                                        'delete' => scheme.error,
                                        _ => scheme.primary,
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SearchHighlightText(
                                          text: title,
                                          query: _query,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SearchHighlightText(
                                          text: priceLine,
                                          query: _query,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SearchHighlightText(
                                          text: meta,
                                          query: _query,
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
                                  if (!_itemScoped)
                                    IconButton(
                                      tooltip: '이 부품 이력',
                                      onPressed: () => _openItemHistory(log),
                                      icon: const Icon(Icons.list_alt_rounded),
                                    ),
                                ],
                              ),
                            ),
                          ),
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

class _SupportUnitPriceChangeDetail extends StatelessWidget {
  const _SupportUnitPriceChangeDetail({
    required this.log,
    required this.showItemHistory,
    required this.onOpenItemHistory,
  });

  final SupportUnitPriceChangeLog log;
  final bool showItemHistory;
  final VoidCallback onOpenItemHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final title = supportUnitPriceChangeLogTitle(log);
    final action = supportUnitPriceActionLabel(log.action);
    final who = log.userName.trim().isEmpty ? '알 수 없음' : log.userName.trim();
    final priceChanged =
        log.action == 'update' && log.oldPrice != log.newPrice;
    final delta = priceChanged
        ? (log.newPrice ?? 0) - (log.oldPrice ?? 0)
        : 0;
    final deltaColor = delta > 0
        ? AppTokens.success(scheme)
        : delta < 0
        ? scheme.error
        : scheme.onSurface;
    final fields = _changedFields(log);
    final maxHeight = (media.size.height - media.viewPadding.top - 56)
        .clamp(160.0, media.size.height * 0.72);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + media.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: switch (log.action) {
                        'create' => AppTokens.success(
                          scheme,
                        ).withValues(alpha: 0.16),
                        'delete' => scheme.errorContainer,
                        _ => scheme.primaryContainer,
                      },
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: switch (log.action) {
                          'create' => AppTokens.success(scheme),
                          'delete' => scheme.error,
                          _ => scheme.primary,
                        },
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatSeoulDateTimeDots(log.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                who,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _priceBlock(
                scheme: scheme,
                deltaColor: deltaColor,
                priceChanged: priceChanged,
              ),
              if (fields.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '변경 항목',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            field.$1,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(child: _fromToText(scheme, field.$2, field.$3)),
                      ],
                    ),
                  ),
              ],
              if (showItemHistory) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: onOpenItemHistory,
                  child: Text('$title 이력 보기'),
                ),
              ],
            ],
          ),
        ),
      );
  }

  Widget _priceBlock({
    required ColorScheme scheme,
    required Color deltaColor,
    required bool priceChanged,
  }) {
    if (log.action == 'create') {
      return Text(
        formatSupportUnitPriceWon(log.newPrice),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppTokens.customerSupportAccent(scheme),
        ),
      );
    }
    if (log.action == 'delete') {
      return Text(
        formatSupportUnitPriceWon(log.oldPrice),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: scheme.error,
        ),
      );
    }
    if (!priceChanged) {
      return Text(
        '${formatSupportUnitPriceWon(log.newPrice ?? log.oldPrice)} · 단가 그대로',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatSupportUnitPriceWon(log.oldPrice),
          style: TextStyle(
            fontSize: 16,
            color: scheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatSupportUnitPriceWon(log.newPrice),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: deltaColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          describeSupportUnitPriceDelta(log.oldPrice, log.newPrice),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: deltaColor,
          ),
        ),
      ],
    );
  }

  Widget _fromToText(ColorScheme scheme, String from, String to) {
    if (from.isEmpty) return Text(to);
    if (to.isEmpty) return Text(from);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: from,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const TextSpan(text: '  →  '),
          TextSpan(
            text: to,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  List<(String, String, String)> _changedFields(SupportUnitPriceChangeLog log) {
    String show(String? value) {
      final t = (value ?? '').trim();
      return t.isEmpty ? '-' : t;
    }

    final out = <(String, String, String)>[];
    void add(String label, String? oldV, String? newV) {
      final a = show(oldV);
      final b = show(newV);
      if (log.action == 'create') {
        if (b == '-') return;
        out.add((label, '', b));
        return;
      }
      if (log.action == 'delete') {
        if (a == '-') return;
        out.add((label, a, ''));
        return;
      }
      if (a != b) out.add((label, a, b));
    }

    if (log.action == 'update') add('품명', log.oldName, log.newName);
    add('규격', log.oldSpec, log.newSpec);
    add('비고', log.oldNote, log.newNote);
    return out;
  }
}

class _UnitPriceEditorResult {
  const _UnitPriceEditorResult.save(this.item, {this.pendingImagePath})
    : delete = false;
  const _UnitPriceEditorResult.delete()
    : item = null,
      pendingImagePath = null,
      delete = true;

  final SupportUnitPriceItem? item;
  final String? pendingImagePath;
  final bool delete;
}

class _SupportUnitPriceEditor extends ConsumerStatefulWidget {
  const _SupportUnitPriceEditor({
    this.existing,
    this.productLines = const [],
    this.categoriesByLine = const {},
    this.laborWorkTypes = const [],
    this.laborSpecsByWork = const {},
  });

  final SupportUnitPriceItem? existing;
  final List<String> productLines;
  final Map<String, List<String>> categoriesByLine;
  final List<String> laborWorkTypes;
  final Map<String, List<String>> laborSpecsByWork;

  @override
  ConsumerState<_SupportUnitPriceEditor> createState() =>
      _SupportUnitPriceEditorState();
}

class _SupportUnitPriceEditorState
    extends ConsumerState<_SupportUnitPriceEditor> {
  static const _customKey = '__custom__';

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _competitorCtrl;
  late String _unitSelect;
  late final TextEditingController _lineCustomCtrl;
  late final TextEditingController _catCustomCtrl;
  late String _lineSelect;
  late String _ohdKindSelect;
  late String _catSelect;
  late String _workSelect;
  late String _specSelect;
  late final TextEditingController _specCustomCtrl;
  late String _imageUrl;
  String? _pendingImagePath;
  late bool _editing;
  late bool _isLabor;

  bool get _isNew => widget.existing == null;

  String get _resolvedLine => _lineSelect == _customKey
      ? _lineCustomCtrl.text.trim()
      : _lineSelect;

  String get _resolvedCategory => _isLabor
      ? '인건비'
      : (_catSelect == _customKey
            ? _catCustomCtrl.text.trim()
            : _catSelect);

  String get _resolvedWork => _workSelect == _customKey
      ? _nameCtrl.text.trim()
      : _workSelect;

  String get _resolvedSpec => _specSelect == _customKey
      ? _specCustomCtrl.text.trim()
      : _specSelect;

  List<String> get _categoryOptions =>
      widget.categoriesByLine[_resolvedLine] ?? const [];

  List<String> get _workOptions => widget.laborWorkTypes;

  List<String> get _specOptions {
    final seen = <String>{};
    final out = <String>[];
    for (final specs in widget.laborSpecsByWork.values) {
      for (final spec in specs) {
        if (seen.add(spec)) out.add(spec);
      }
    }
    out.sort();
    return out;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl = TextEditingController(
      text: e?.price == null ? '' : NumberFormat('#,###').format(e!.price),
    );
    final competitor = e?.displayCompetitorPrice;
    _competitorCtrl = TextEditingController(
      text: competitor == null ? '' : NumberFormat('#,###').format(competitor),
    );
    _noteCtrl = TextEditingController(text: e?.displayNote ?? '');
    final unit = normalizeSupportUnitPriceUnit(e?.unit ?? '');
    _unitSelect = unit.isEmpty ? kSupportUnitPriceUnits.first : unit;
    final rawLine = (e?.productLine ?? '').trim();
    final family = supportUnitPriceFamily(rawLine);
    if (kSupportUnitPriceFamilies.contains(family)) {
      _lineSelect = family;
      _lineCustomCtrl = TextEditingController();
    } else if (family.isNotEmpty && family != '미분류') {
      _lineSelect = _customKey;
      _lineCustomCtrl = TextEditingController(text: family);
    } else {
      _lineSelect = kSupportUnitPriceFamilies.first;
      _lineCustomCtrl = TextEditingController();
    }
    _ohdKindSelect = supportUnitPriceOhdKind(rawLine);
    if (!(e?.isLabor ?? false) &&
        family == 'OHD' &&
        _ohdKindSelect.isEmpty) {
      _ohdKindSelect = kSupportUnitPriceOhdKinds.first;
    }
    final cat = (e?.category ?? '').trim();
    final cats = widget.categoriesByLine[_lineSelect] ?? const [];
    if (cat.isNotEmpty && cats.contains(cat)) {
      _catSelect = cat;
      _catCustomCtrl = TextEditingController();
    } else if (cat.isNotEmpty) {
      _catSelect = _customKey;
      _catCustomCtrl = TextEditingController(text: cat);
    } else if (cats.isNotEmpty) {
      _catSelect = cats.first;
      _catCustomCtrl = TextEditingController();
    } else {
      _catSelect = _customKey;
      _catCustomCtrl = TextEditingController();
    }
    _imageUrl = e?.imageUrl ?? '';
    _editing = e == null;
    _isLabor = e?.isLabor ?? false;
    final work = (e?.name ?? '').trim();
    if (_isLabor && work.isNotEmpty && widget.laborWorkTypes.contains(work)) {
      _workSelect = work;
    } else if (_isLabor && work.isNotEmpty) {
      _workSelect = _customKey;
    } else if (_isLabor && widget.laborWorkTypes.isNotEmpty) {
      _workSelect = widget.laborWorkTypes.first;
    } else {
      _workSelect = _customKey;
    }
    final spec = (e?.spec ?? '').trim();
    final specs = widget.laborSpecsByWork[_workSelect] ?? const [];
    if (_isLabor && spec.isNotEmpty && specs.contains(spec)) {
      _specSelect = spec;
      _specCustomCtrl = TextEditingController();
    } else if (_isLabor && spec.isNotEmpty) {
      _specSelect = _customKey;
      _specCustomCtrl = TextEditingController(text: spec);
    } else if (_isLabor && specs.isNotEmpty) {
      _specSelect = specs.first;
      _specCustomCtrl = TextEditingController();
    } else {
      _specSelect = _customKey;
      _specCustomCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _noteCtrl.dispose();
    _competitorCtrl.dispose();
    _lineCustomCtrl.dispose();
    _catCustomCtrl.dispose();
    _specCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showSalesCallImageSourceSheet(context, title: '부품 사진');
    if (source == null || !mounted) return;
    String? path;
    if (source == SalesCallImageSource.camera) {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      path = shot?.path;
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      path = result?.files.first.path;
    }
    if (path == null || path.isEmpty || !mounted) return;
    setState(() => _pendingImagePath = path);
  }

  Future<void> _confirmDelete() async {
    final name = widget.existing?.name ?? '이 단가';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('단가 삭제'),
        content: Text('$name을(를) 삭제할까요?\n삭제해도 변경 이력은 남습니다.'),
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
    if (ok == true && mounted) {
      Navigator.of(context).pop(const _UnitPriceEditorResult.delete());
    }
  }

  void _openItemHistory(SupportUnitPriceItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportUnitPriceHistoryScreen(
          itemId: item.id,
          itemName: item.name,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final existing = widget.existing;
    final name = _isLabor
        ? _resolvedWork
        : (_nameCtrl.text.trim().isEmpty
              ? (existing?.name ?? '')
              : _nameCtrl.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_isLabor ? '작업종류를 입력해 주세요.' : '품명을 입력해 주세요.')),
      );
      return;
    }
    if (_resolvedLine.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제품군을 입력해 주세요.')));
      return;
    }
    final price = int.tryParse(_priceCtrl.text.replaceAll(',', '').trim());
    final newPrice = (price ?? 0) > 0 ? price : null;
    final competitor = int.tryParse(
      _competitorCtrl.text.replaceAll(',', '').trim(),
    );
    final newCompetitor = (competitor ?? 0) > 0 ? competitor : null;
    final family = _resolvedLine;
    final line = encodeSupportUnitPriceProductLine(
      family: family,
      ohdKind: _ohdKindSelect,
      labor: _isLabor,
    );
    final category = _resolvedCategory;
    final spec = _isLabor ? _resolvedSpec : (existing?.spec ?? '');
    final unit = _isLabor ? '' : _unitSelect;
    final note = _noteCtrl.text.trim();
    if (existing != null) {
      final nameChanged = name != existing.name.trim();
      final priceChanged = newPrice != existing.price;
      final competitorChanged =
          newCompetitor != existing.displayCompetitorPrice;
      final noteChanged = note != existing.displayNote;
      final lineChanged = line != existing.productLine.trim();
      final categoryChanged = category != existing.category.trim();
      final specChanged = spec != existing.spec.trim();
      final unitChanged = unit != existing.unit.trim();
      final kindChanged = _isLabor != existing.isLabor;
      final imageChanged = _pendingImagePath != null;
      if (!nameChanged &&
          !priceChanged &&
          !competitorChanged &&
          !noteChanged &&
          !lineChanged &&
          !categoryChanged &&
          !specChanged &&
          !unitChanged &&
          !kindChanged &&
          !imageChanged) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('변경된 내용이 없습니다.')));
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('단가 저장'),
          content: Text(
            describeSupportUnitPriceSaveConfirm(
              name: name,
              isNew: false,
              oldPrice: existing.price,
              newPrice: newPrice,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    Navigator.of(context).pop(
      _UnitPriceEditorResult.save(
        SupportUnitPriceItem(
          id: existing?.id ?? '',
          name: name,
          nameEn: existing?.nameEn ?? '',
          spec: spec,
          price: newPrice,
          competitorPrice: newCompetitor,
          note: note,
          productLine: line,
          category: category,
          unit: unit,
          kind: _isLabor
              ? kSupportUnitPriceKindLabor
              : kSupportUnitPriceKindPart,
          imageUrl: _imageUrl,
          diagramUrl: existing?.diagramUrl ?? '',
        ),
        pendingImagePath: _pendingImagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final existing = widget.existing;
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom + media.padding.bottom;
    final lineOptions = [
      ...widget.productLines,
      if (_lineSelect != _customKey &&
          _lineSelect.isNotEmpty &&
          !widget.productLines.contains(_lineSelect))
        _lineSelect,
    ];
    final catOptions = [
      ..._categoryOptions,
      if (_catSelect != _customKey &&
          _catSelect.isNotEmpty &&
          !_categoryOptions.contains(_catSelect))
        _catSelect,
    ];
    final unitItems = [
      ...kSupportUnitPriceUnits,
      if (_unitSelect.isNotEmpty &&
          !kSupportUnitPriceUnits.contains(_unitSelect))
        _unitSelect,
    ];
    final workOptions = [
      ..._workOptions,
      if (_workSelect != _customKey &&
          _workSelect.isNotEmpty &&
          !_workOptions.contains(_workSelect))
        _workSelect,
    ];
    final specOptions = [
      ..._specOptions,
      if (_specSelect != _customKey &&
          _specSelect.isNotEmpty &&
          !_specOptions.contains(_specSelect))
        _specSelect,
    ];
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );
    final boxBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    InputDecoration boxDeco({String? hint, String? suffix}) {
      return InputDecoration(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        hintText: hint,
        suffixText: suffix,
        border: boxBorder,
        enabledBorder: boxBorder,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      );
    }

    Widget fieldLabel(String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: labelStyle),
      );
    }

    Widget labeled(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel(label),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget selectOrCustom({
      required String label,
      required String hint,
      required String selected,
      required List<String> options,
      required ValueChanged<String> onSelect,
      required TextEditingController customCtrl,
    }) {
      final value = selected == _customKey || options.contains(selected)
          ? selected
          : _customKey;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fieldLabel(label),
          InputDecorator(
            decoration: boxDeco(hint: hint).copyWith(
              contentPadding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: options.isEmpty && value != _customKey ? _customKey : value,
                hint: Text(hint),
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                items: [
                  ...options.map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _customKey,
                    child: Text('직접 입력'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onSelect(v);
                },
              ),
            ),
          ),
          if (value == _customKey) ...[
            const SizedBox(height: 8),
            TextField(
              controller: customCtrl,
              decoration: boxDeco(hint: '$label 이름을 입력하세요'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      );
    }

    Widget sectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppTokens.customerSupportAccent(scheme),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isNew
                          ? '단가 입력'
                          : _editing
                          ? '단가 수정'
                          : '단가',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_editing) ...[
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('부품')),
                          ButtonSegment(value: true, label: Text('인건비')),
                        ],
                        selected: {_isLabor},
                        onSelectionChanged: (next) {
                          setState(() {
                            _isLabor = next.first;
                            if (_isLabor &&
                                widget.laborWorkTypes.isNotEmpty &&
                                _workSelect == _customKey) {
                              _workSelect = widget.laborWorkTypes.first;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      sectionTitle('1. 분류'),
                      selectOrCustom(
                        label: '제품군',
                        hint: 'WMS / SPD / OHD 선택',
                        selected: _lineSelect,
                        options: lineOptions,
                        customCtrl: _lineCustomCtrl,
                        onSelect: (v) {
                          setState(() {
                            _lineSelect = v;
                            if (v != 'OHD') _ohdKindSelect = '';
                            final cats = widget.categoriesByLine[v] ?? const [];
                            if (cats.contains(_catSelect)) return;
                            if (cats.isNotEmpty) {
                              _catSelect = cats.first;
                              _catCustomCtrl.clear();
                            } else {
                              _catSelect = _customKey;
                            }
                          });
                        },
                      ),
                      if (!_isLabor &&
                          supportUnitPriceFamily(_resolvedLine) == 'OHD') ...[
                        const SizedBox(height: 12),
                        fieldLabel('기종'),
                        InputDecorator(
                          decoration: boxDeco(
                            hint: '수납형 / 산업용 / 주택차고문',
                          ).copyWith(
                            contentPadding: const EdgeInsets.fromLTRB(
                              4,
                              2,
                              4,
                              2,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value:
                                  kSupportUnitPriceOhdKinds.contains(
                                    _ohdKindSelect,
                                  )
                                  ? _ohdKindSelect
                                  : kSupportUnitPriceOhdKinds.first,
                              icon: Icon(
                                Icons.expand_more_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                              items: [
                                for (final k in kSupportUnitPriceOhdKinds)
                                  DropdownMenuItem(value: k, child: Text(k)),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _ohdKindSelect = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_isLabor)
                        selectOrCustom(
                          label: '구분',
                          hint: '타사자동문, 주택차고문 등 선택',
                          selected: _specSelect,
                          options: specOptions,
                          customCtrl: _specCustomCtrl,
                          onSelect: (v) => setState(() => _specSelect = v),
                        )
                      else
                        selectOrCustom(
                          label: '구분',
                          hint: 'CONTROLLER, MOTOR 등 선택',
                          selected: _catSelect,
                          options: catOptions,
                          customCtrl: _catCustomCtrl,
                          onSelect: (v) => setState(() => _catSelect = v),
                        ),
                      const SizedBox(height: 16),
                      sectionTitle('2. 품목'),
                    ] else ...[
                      labeled(
                        '제품군',
                        supportUnitPriceFamily(existing?.productLine ?? ''),
                      ),
                      if (!_isLabor &&
                          supportUnitPriceOhdKind(
                            existing?.productLine ?? '',
                          ).isNotEmpty)
                        labeled(
                          '기종',
                          supportUnitPriceOhdKind(existing?.productLine ?? ''),
                        ),
                      labeled(
                        '구분',
                        existing == null
                            ? ''
                            : supportUnitPriceGroupCategory(existing),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isLabor) ...[
                          Column(
                            children: [
                              if (_editing) fieldLabel('사진'),
                              GestureDetector(
                                onTap: _editing
                                    ? _pickImage
                                    : (existing != null &&
                                          existing.photoUrls.isNotEmpty)
                                    ? () => showSupportUnitPricePhotos(
                                        context,
                                        existing,
                                      )
                                    : null,
                                child: Stack(
                                  children: [
                                    SupportUnitPricePhoto(
                                      url: _pendingImagePath ?? _imageUrl,
                                      width: 72,
                                      height: 72,
                                    ),
                                    if (_editing)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: scheme.onPrimary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _editing
                              ? (_isLabor
                                    ? selectOrCustom(
                                        label: '품명',
                                        hint: '판넬 교체, 모터 교체 등 선택',
                                        selected: _workSelect,
                                        options: workOptions,
                                        customCtrl: _nameCtrl,
                                        onSelect: (v) =>
                                            setState(() => _workSelect = v),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          fieldLabel('품명'),
                                          TextField(
                                            controller: _nameCtrl,
                                            autofocus: _isNew,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: boxDeco(
                                              hint: '품명을 입력하세요',
                                            ),
                                          ),
                                        ],
                                      ))
                              : labeled('품명', existing?.name ?? ''),
                        ),
                      ],
                    ),
                    if (_editing) ...[
                      if (!_isLabor) ...[
                        const SizedBox(height: 12),
                        fieldLabel('단위'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final u in unitItems)
                              ChoiceChip(
                                label: Text(u),
                                selected: _unitSelect == u,
                                onSelected: (_) =>
                                    setState(() => _unitSelect = u),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      sectionTitle('3. 금액'),
                      fieldLabel('단가'),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          const ThousandsFormatter(),
                        ],
                        decoration: boxDeco(hint: '85,000', suffix: '원'),
                      ),
                      const SizedBox(height: 12),
                      fieldLabel('타사'),
                      TextField(
                        controller: _competitorCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          const ThousandsFormatter(),
                        ],
                        decoration: boxDeco(hint: '없으면 비움', suffix: '원'),
                      ),
                      const SizedBox(height: 12),
                      fieldLabel('비고'),
                      TextField(
                        controller: _noteCtrl,
                        decoration: boxDeco(hint: '선택 사항'),
                      ),
                    ] else ...[
                      if (!_isLabor) labeled('단위', existing?.unit ?? ''),
                      labeled(
                        '단가',
                        existing?.price == null
                            ? '-'
                            : '${NumberFormat('#,###').format(existing!.price)}원',
                      ),
                      if (existing?.displayCompetitorPrice != null)
                        labeled(
                          '타사',
                          formatSupportUnitPriceCompetitor(
                            existing!.displayCompetitorPrice,
                          ),
                        ),
                      if ((existing?.displayNote ?? '').isNotEmpty)
                        labeled('비고', existing!.displayNote),
                    ],
                    if (existing != null) ...[
                      const SizedBox(height: 8),
                      if (existing.updatedByName.trim().isNotEmpty ||
                          existing.updatedAt != null)
                        Text(
                          [
                            if (existing.updatedByName.trim().isNotEmpty)
                              existing.updatedByName.trim(),
                            if (existing.updatedAt != null)
                              formatSeoulDateTimeDots(existing.updatedAt!),
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _openItemHistory(existing),
                          child: const Text('변경 이력 보기'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_editing && existing != null)
                  TextButton(
                    onPressed: _confirmDelete,
                    child: const Text('삭제'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                const Spacer(),
                if (_editing)
                  FilledButton(onPressed: _save, child: const Text('저장'))
                else
                  FilledButton(
                    onPressed: () => setState(() => _editing = true),
                    child: const Text('수정'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
