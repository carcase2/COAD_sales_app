import 'dart:async';

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/quoter/quoter_providers.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/quoter/shutter_lowest_quote.dart';
import 'package:coad_customer_calls/features/quoter/shutter_size_quote.dart';
import 'package:coad_customer_calls/features/quoter/size_first_quote.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_repository.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 폭·높이를 먼저 넣고, 그 사이즈의 모델 단가를 비교한 뒤 세부 견적으로 들어간다.
class SizeFirstQuoteScreen extends ConsumerStatefulWidget {
  const SizeFirstQuoteScreen({super.key});

  @override
  ConsumerState<SizeFirstQuoteScreen> createState() =>
      _SizeFirstQuoteScreenState();
}

class _SizeFirstQuoteScreenState extends ConsumerState<SizeFirstQuoteScreen> {
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _widthFocus = FocusNode();
  final _heightFocus = FocusNode();
  final _won = NumberFormat('#,###');
  StandardUnitPriceCatalog? _catalog;
  Map<String, List<StandardPriceCell>> _cellsByModel = {};
  String? _categoryId;
  bool _editingWidth = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _widthFocus.dispose();
    _heightFocus.dispose();
    super.dispose();
  }

  void _track(String key) {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    UsageService.recordTab(userId: user.id, userName: user.name, tabKey: key);
  }

  StandardUnitPriceRepository get _repo =>
      ref.read(standardUnitPriceRepositoryProvider);

  int get _widthMm =>
      int.tryParse(_widthCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  int get _heightMm =>
      int.tryParse(_heightCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  bool get _hasSize => _widthMm > 0 && _heightMm > 0;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _repo.fetchCatalog();
      final rows = await _repo.fetchAllPrices();
      final cells = <String, List<StandardPriceCell>>{};
      for (final row in rows) {
        cells.putIfAbsent(row.modelId, () => []).add(row.asCell);
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _cellsByModel = cells;
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

  void _setAxis(bool width, int mm) {
    final ctrl = width ? _widthCtrl : _heightCtrl;
    ctrl.text = '$mm';
    if (width) {
      setState(() => _editingWidth = false);
      _heightFocus.requestFocus();
      return;
    }
    setState(() => _editingWidth = false);
    _widthFocus.unfocus();
    _heightFocus.unfocus();
  }

  List<SizeFirstOffer> get _offers {
    final catalog = _catalog;
    if (catalog == null || !_hasSize) return const [];
    final shutterOnly = _categoryId == kShutterQuoteCategoryId;
    final catalogOffers = sizeFirstOffers(
      categories: catalog.orderedCategories,
      models: catalog.models,
      cellsByModel: _cellsByModel,
      widthMm: _widthMm,
      heightMm: _heightMm,
      categoryId: shutterOnly ? kShutterQuoteCategoryId : _categoryId,
    );
    if (_categoryId != null && !shutterOnly) return catalogOffers;
    return [
      ...catalogOffers,
      ...shutterSizeOffers(
        existing: catalogOffers,
        widthMm: _widthMm,
        heightMm: _heightMm,
      ),
    ];
  }

  Future<void> _openWriter(SizeFirstOffer offer) async {
    final type = offer.shutterType;
    if (type != null) {
      await _openShutterQuote(type, offer.modelName);
      return;
    }
    final price = offer.quote.price;
    if (price == null) {
      await _explainMissing(offer);
      return;
    }
    final saved = await pushSizeQuoteEditor(
      context,
      seed: SizeQuoteSeed(
        categoryId: offer.categoryId,
        categoryName: offer.categoryName,
        modelId: offer.modelId,
        modelName: offer.modelName,
        widthMm: _widthMm,
        heightMm: _heightMm,
        standardPrice: price,
      ),
    );
    if (!mounted || saved == null || saved.openExport) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('견적서를 저장했습니다.')));
  }

  /// 셔터는 기존 산출 화면에서 내역·기술 사양·제조사를 본 뒤 견적서를 쓴다.
  Future<void> _openShutterQuote(ShutterType type, String modelName) async {
    _track('shutter_quoter');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(modelName)),
          body: QuoterScreen(
            showQuickActions: false,
            initialType: type,
            initialWidthMm: _widthMm,
            initialHeightMm: _heightMm,
          ),
        ),
      ),
    );
  }

  void _openPriceTable() {
    _track('standard_unit_price');
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const StandardUnitPriceScreen()),
    );
  }

  void _onOfferTap(SizeFirstOffer offer) {
    unawaited(_openWriter(offer));
  }

  Map<ShutterType, ShutterLowestQuote> _shutterQuotes() {
    if (!_hasSize) return const {};
    final prices = ref.watch(shutterPricesFutureProvider).asData?.value;
    if (prices == null) return const {};
    final quotes = <ShutterType, ShutterLowestQuote>{};
    for (final type in ShutterType.values) {
      try {
        final run = runLowestShutterQuote(
          type: type,
          widthMm: _widthMm,
          heightMm: _heightMm,
          prices: prices,
        );
        if (run.result.totalAmount > 0) quotes[type] = run;
      } catch (_) {}
    }
    return quotes;
  }

  int? _shownPrice(
    SizeFirstOffer offer,
    Map<ShutterType, ShutterLowestQuote> shutterQuotes,
  ) {
    final type = offer.shutterType;
    if (type != null) {
      final total = shutterQuotes[type]?.result.totalAmount;
      if (total != null && total > 0) return total;
    }
    return offer.quote.price;
  }

  Future<void> _explainMissing(SizeFirstOffer offer) async {
    final lookup = describeSizeLookup(offer.quote.inference);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                offer.modelName,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${offer.categoryName} · $_widthMm × $_heightMm',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                offer.isShutter ? '이 사이즈는 셔터 견적이 없습니다' : '이 사이즈는 단가가 없습니다',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                offer.isShutter ? '셔터 단가로 합계를 계산하지 못했습니다.' : lookup,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoading(message: '단가 불러오는 중…');
    if (_error != null) {
      return AppErrorState(
        message: koreanErrorMessage(_error!),
        onRetry: _load,
      );
    }
    final catalog = _catalog;
    if (catalog == null) {
      return const AppLoading(message: '단가 불러오는 중…');
    }
    final pricesAsync = ref.watch(shutterPricesFutureProvider);
    final shutterCalculating = pricesAsync.isLoading && !pricesAsync.hasValue;
    final shutterQuotes = _shutterQuotes();
    final offers = [..._offers]
      ..sort((a, b) {
        final ap = _shownPrice(a, shutterQuotes);
        final bp = _shownPrice(b, shutterQuotes);
        if (ap == null && bp == null) return a.modelName.compareTo(b.modelName);
        if (ap == null) return 1;
        if (bp == null) return -1;
        final byPrice = ap.compareTo(bp);
        if (byPrice != 0) return byPrice;
        final byCat = a.categoryName.compareTo(b.categoryName);
        if (byCat != 0) return byCat;
        return a.modelName.compareTo(b.modelName);
      });
    final priced = offers
        .where((offer) => _shownPrice(offer, shutterQuotes) != null)
        .length;
    final garageOnly =
        _categoryId != null &&
        catalog.categories.any(
          (cat) => cat.id == _categoryId && cat.name == '차고문',
        );
    final heightChips = garageOnly
        ? garageQuickHeights
        : _categoryId == null
        ? [...standardQuickHeights, ...garageQuickHeights]
        : standardQuickHeights;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _hasSize ? '낮은 단가 순 · 단가 $priced개' : '폭과 높이를 먼저 넣으세요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _openPriceTable,
                child: const Text('단가표'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _SizeField(
                  label: '폭',
                  controller: _widthCtrl,
                  focusNode: _widthFocus,
                  selected: _editingWidth,
                  onTap: () => setState(() => _editingWidth = true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: _SizeField(
                  label: '높이',
                  controller: _heightCtrl,
                  focusNode: _heightFocus,
                  selected: !_editingWidth,
                  onTap: () => setState(() => _editingWidth = false),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            children: [
              for (final mm
                  in (_editingWidth ? standardQuickWidths : heightChips))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      mm == 2150
                          ? '2150 4단'
                          : mm == 2700
                          ? '2700 5단'
                          : '$mm',
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _setAxis(_editingWidth, mm);
                    },
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('전체'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('셔터'),
                  selected: _categoryId == kShutterQuoteCategoryId,
                  onSelected: (_) =>
                      setState(() => _categoryId = kShutterQuoteCategoryId),
                ),
              ),
              for (final cat in catalog.orderedCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(cat.name),
                    selected: _categoryId == cat.id,
                    onSelected: (_) => setState(() => _categoryId = cat.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: !_hasSize
              ? const Center(child: Text('폭과 높이를 넣으면 모델별 단가가 나옵니다.'))
              : offers.isEmpty
              ? const Center(child: Text('이 분류에 모델이 없습니다.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: offers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    final price = _shownPrice(offer, shutterQuotes);
                    final cheapest =
                        price != null &&
                        offers.indexWhere(
                              (item) =>
                                  _shownPrice(item, shutterQuotes) != null,
                            ) ==
                            index;
                    return _OfferTile(
                      offer: offer,
                      price: price,
                      won: _won,
                      cheapest: cheapest,
                      calculating:
                          offer.isShutter &&
                          price == null &&
                          shutterCalculating,
                      onTap: () => _onOfferTap(offer),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'mm',
        isDense: true,
        filled: selected,
        fillColor: scheme.primaryContainer.withValues(alpha: 0.45),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.price,
    required this.won,
    required this.cheapest,
    required this.calculating,
    required this.onTap,
  });

  final SizeFirstOffer offer;
  final int? price;
  final NumberFormat won;
  final bool cheapest;
  final bool calculating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = price == null;
    final fromShutter = offer.isShutter && price != null;
    final label = calculating
        ? '계산 중'
        : missing
        ? (offer.quote.inference.outOfRange ? '범위 초과' : '단가 없음')
        : '${won.format(price)}원';
    final subtitle = [
      offer.categoryName,
      if (!missing && !fromShutter && offer.quote.inference.isEstimated) '추정',
      if (cheapest) '최저',
    ].join(' · ');
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 36,
                decoration: BoxDecoration(
                  color: hexToColor(offer.color),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.modelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: missing ? scheme.onSurfaceVariant : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
