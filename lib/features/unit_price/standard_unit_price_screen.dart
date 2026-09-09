import 'dart:async';
import 'dart:convert';

import 'package:coad_customer_calls/core/utils/korean_amount_words.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/quoter/quoter_formatters.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/size_quote_repository.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_export.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_promo_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_models.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_repository.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

bool canViewStandardUnitPrice(AppUser? user) {
  return user != null;
}

/// 단가 수정은 인트라넷에서만 한다. 앱은 조회 전용.
bool canEditStandardUnitPrice(AppUser? user) => false;

class StandardUnitPriceScreen extends ConsumerStatefulWidget {
  const StandardUnitPriceScreen({super.key, this.showAppBar = true});

  /// 견적 탭 안에 넣을 때는 false (허브 AppBar·탭과 중복 방지).
  final bool showAppBar;

  @override
  ConsumerState<StandardUnitPriceScreen> createState() =>
      _StandardUnitPriceScreenState();
}

class _StandardUnitPriceScreenState
    extends ConsumerState<StandardUnitPriceScreen> {
  static const _kPrefCat = 'std_unit_price_category';
  static const _kPrefModel = 'std_unit_price_model';
  static const _kPrefW = 'std_unit_price_width';
  static const _kPrefH = 'std_unit_price_height';

  StandardUnitPriceCatalog? _catalog;
  String? _categoryId;
  String? _modelId;
  Map<String, List<StandardUnitPriceRow>> _cellsByModel = {};
  List<StandardUnitPriceAdjustment> _adjustments = const [];
  List<StandardUnitPriceChangeLog> _logs = const [];
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editingWidth = true;
  StandardAdjustType _adjustType = StandardAdjustType.percent;
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _adjustValueCtrl = TextEditingController(text: '0');
  final _adjustReasonCtrl = TextEditingController();
  String? _openAdjustmentId;
  final _won = NumberFormat('#,###');
  final _dt = DateFormat('yyyy.MM.dd HH:mm');
  List<SizeQuoteDocument> _similarQuotes = const [];
  Timer? _similarDebounce;

  List<StandardUnitPriceRow> get _cells =>
      _cellsByModel[_modelId] ?? const [];

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
    _adjustValueCtrl.dispose();
    _adjustReasonCtrl.dispose();
    _similarDebounce?.cancel();
    super.dispose();
  }

  void _openTool(String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        ),
      ),
    );
  }

  StandardUnitPriceRepository get _repo =>
      ref.read(standardUnitPriceRepositoryProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalogFut = _repo.fetchCatalog();
      final allFut = _repo.fetchAllPrices();
      final adjFut = _repo.fetchAdjustments();
      final logsFut = _repo.fetchChangeLogs();
      final catalog = await catalogFut;
      final all = await allFut;
      final adjustments = await adjFut;
      final logs = await logsFut;
      final firstCat = catalog.orderedCategories.isEmpty
          ? null
          : catalog.orderedCategories.first;
      StandardUnitPriceModel? firstModel;
      if (firstCat != null) {
        final inCat = catalog.modelsFor(firstCat.id);
        firstModel = inCat.isEmpty
            ? (catalog.models.isEmpty ? null : catalog.models.first)
            : inCat.first;
      } else if (catalog.models.isNotEmpty) {
        firstModel = catalog.models.first;
      }
      final byModel = <String, List<StandardUnitPriceRow>>{};
      for (final cell in all) {
        byModel.putIfAbsent(cell.modelId, () => []).add(cell);
      }
      if (!mounted) return;
      final prefs = ref.read(appDependenciesProvider).prefs;
      var categoryId = firstCat?.id;
      var modelId = firstModel?.id;
      final savedCat = prefs.getString(_kPrefCat);
      if (savedCat != null &&
          catalog.categories.any((c) => c.id == savedCat)) {
        categoryId = savedCat;
        final inCat = catalog.modelsFor(savedCat);
        final savedModel = prefs.getString(_kPrefModel);
        if (savedModel != null && inCat.any((m) => m.id == savedModel)) {
          modelId = savedModel;
        } else {
          modelId = inCat.isEmpty ? null : inCat.first.id;
        }
      } else {
        final savedModel = prefs.getString(_kPrefModel);
        if (savedModel != null &&
            catalog.models.any((m) => m.id == savedModel)) {
          final matched =
              catalog.models.firstWhere((m) => m.id == savedModel);
          categoryId = matched.categoryId;
          modelId = matched.id;
        }
      }
      final savedW = prefs.getInt(_kPrefW) ?? 0;
      final savedH = prefs.getInt(_kPrefH) ?? 0;
      if (savedW > 0) _widthCtrl.text = _won.format(savedW);
      if (savedH > 0) _heightCtrl.text = _won.format(savedH);
      setState(() {
        _catalog = catalog;
        _categoryId = categoryId;
        _modelId = modelId;
        _cellsByModel = byModel;
        _adjustments = adjustments;
        _logs = logs;
        _loading = false;
      });
      _scheduleSimilarQuotes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _selectCategory(String id) async {
    final catalog = _catalog;
    if (catalog == null) return;
    final next = catalog.modelsFor(id);
    final modelId = next.isEmpty ? null : next.first.id;
    setState(() {
      _categoryId = id;
      _modelId = modelId;
    });
    _persistLookup();
    _scheduleSimilarQuotes();
    if (modelId != null) await _ensureCells(modelId);
  }

  Future<void> _selectModel(String id) async {
    setState(() => _modelId = id);
    _persistLookup();
    _scheduleSimilarQuotes();
    await _ensureCells(id);
  }

  Future<void> _ensureCells(String modelId) async {
    if (_cellsByModel.containsKey(modelId)) return;
    await _reloadCells(modelId);
  }

  Future<void> _exportExcel() async {
    final catalog = _catalog;
    if (catalog == null) return;
    setState(() => _saving = true);
    try {
      final all = await _repo.fetchAllPrices();
      final byModel = <String, List<StandardUnitPriceRow>>{};
      for (final cell in all) {
        byModel.putIfAbsent(cell.modelId, () => []).add(cell);
      }
      final buf = StringBuffer();
      for (final cat in catalog.categories) {
        for (final model in catalog.modelsFor(cat.id)) {
          final cells = byModel[model.id] ?? const <StandardUnitPriceRow>[];
          final axes = gridAxesFromCells(cells.map((c) => c.asCell));
          buf.write(
            buildStandardPriceGridCsv(
              title: '${cat.name} / ${model.name}',
              widths: axes.widths,
              heights: axes.heights,
              cellText: (w, h) {
                for (final cell in cells) {
                  if (cell.widthMm == w && cell.heightMm == h) {
                    if (!cell.available) return 'X';
                    if (cell.price <= 0) return '';
                    return '${cell.price}';
                  }
                }
                return '';
              },
            ),
          );
        }
      }
      final ymd = DateFormat('yyyyMMdd').format(DateTime.now());
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(buf.toString()),
      ]);
      await FileSaver.instance.saveFile(
        name: '표준단가_히트맵_$ymd',
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadCells(String modelId) async {
    try {
      final cells = await _repo.fetchPrices(modelId);
      if (!mounted) return;
      setState(() => _cellsByModel = {..._cellsByModel, modelId: cells});
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  void _writeSize({int? widthMm, int? heightMm}) {
    if (widthMm != null) {
      _widthCtrl.text = widthMm > 0 ? _won.format(widthMm) : '';
    }
    if (heightMm != null) {
      _heightCtrl.text = heightMm > 0 ? _won.format(heightMm) : '';
    }
    setState(() {});
    _persistLookup();
    _scheduleSimilarQuotes();
  }

  void _scheduleSimilarQuotes() {
    _similarDebounce?.cancel();
    _similarDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadSimilarQuotes());
    });
  }

  Future<void> _loadSimilarQuotes() async {
    final modelId = _modelId;
    if (!_hasSize || modelId == null) {
      if (mounted) setState(() => _similarQuotes = const []);
      return;
    }
    try {
      final rows = await ref.read(sizeQuoteRepositoryProvider).listSimilar(
            modelId: modelId,
            widthMm: _widthMm,
            heightMm: _heightMm,
          );
      if (!mounted) return;
      setState(() => _similarQuotes = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _similarQuotes = const []);
    }
  }

  SizeQuoteSeed? get _quoteSeed {
    final cat = _selectedCategory;
    final model = _selectedModel;
    if (cat == null || model == null || !_hasSize) return null;
    final price = _inference.estimatedPrice ?? 0;
    if (price <= 0 || _inference.outOfRange) return null;
    return SizeQuoteSeed(
      categoryId: cat.id,
      categoryName: cat.name,
      modelId: model.id,
      modelName: model.name,
      widthMm: _widthMm,
      heightMm: _heightMm,
      standardPrice: price,
    );
  }

  Future<void> _openQuoteWriter({SizeQuoteDocument? existing}) async {
    final seed = _quoteSeed;
    if (existing == null && seed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사이즈와 단가를 먼저 확인한 뒤 견적서를 작성하세요.')),
      );
      return;
    }
    await pushSizeQuoteEditor(
      context,
      existing: existing,
      seed: seed,
    );
    if (mounted) unawaited(_loadSimilarQuotes());
  }

  Future<void> _openQuoteHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SizeQuoteWriterScreen(seed: _quoteSeed),
      ),
    );
    if (mounted) unawaited(_loadSimilarQuotes());
  }

  Future<void> _openPromoImages() async {
    final catalog = _catalog;
    if (catalog == null) return;
    await pushSizeQuotePromoScreen(
      context,
      catalog: catalog,
      modelId: _selectedModel?.id,
      modelName: _selectedModel?.name,
    );
  }

  Future<void> _openSimilarQuotes() async {
    await showSizeQuoteSimilarSheet(
      context,
      items: _similarQuotes,
      modelName: _selectedModel?.name ?? '',
      widthMm: _widthMm,
      heightMm: _heightMm,
      onOpen: (doc) => unawaited(
        showSizeQuoteExportSheet(context, doc: doc).then((_) {
          if (mounted) unawaited(_loadSimilarQuotes());
        }),
      ),
    );
  }

  void _persistLookup() {
    final prefs = ref.read(appDependenciesProvider).prefs;
    if (_categoryId != null) {
      unawaited(prefs.setString(_kPrefCat, _categoryId!));
    }
    if (_modelId != null) {
      unawaited(prefs.setString(_kPrefModel, _modelId!));
    }
    unawaited(prefs.setInt(_kPrefW, _widthMm));
    unawaited(prefs.setInt(_kPrefH, _heightMm));
  }

  void _setEditingWidth(bool width) {
    HapticFeedback.selectionClick();
    setState(() => _editingWidth = width);
  }

  /// 입력 중인 칸을 다시 누르면 지우고 처음부터 입력.
  void _tapSizeAxis(bool width) {
    HapticFeedback.selectionClick();
    if (_editingWidth == width) {
      if (width) {
        _writeSize(widthMm: 0);
      } else {
        _writeSize(heightMm: 0);
      }
      return;
    }
    setState(() => _editingWidth = width);
  }

  void _quickWidth(int mm) {
    HapticFeedback.selectionClick();
    _writeSize(widthMm: mm);
  }

  void _quickHeight(int mm) {
    HapticFeedback.selectionClick();
    _writeSize(heightMm: mm);
  }

  int get _currentAxisMm => _editingWidth ? _widthMm : _heightMm;

  void _appendDigit(String d) {
    HapticFeedback.selectionClick();
    final cur = _currentAxisMm;
    final raw = cur == 0 ? d.replaceFirst(RegExp(r'^0+'), '') : '$cur$d';
    if (raw.isEmpty) {
      if (_editingWidth) {
        _writeSize(widthMm: 0);
      } else {
        _writeSize(heightMm: 0);
      }
      return;
    }
    final next = int.tryParse(raw);
    if (next == null || next > 99999) return;
    if (_editingWidth) {
      _writeSize(widthMm: next);
    } else {
      _writeSize(heightMm: next);
    }
  }

  void _backspaceSize() {
    HapticFeedback.selectionClick();
    final s = '$_currentAxisMm';
    final next = s.length <= 1 ? 0 : (int.tryParse(s.substring(0, s.length - 1)) ?? 0);
    if (_editingWidth) {
      _writeSize(widthMm: next);
    } else {
      _writeSize(heightMm: next);
    }
  }

  void _clearCurrentAxis() {
    HapticFeedback.selectionClick();
    if (_editingWidth) {
      _writeSize(widthMm: 0);
    } else {
      _writeSize(heightMm: 0);
    }
  }

  void _openGridSheet() {
    if (_catalog == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.72;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedCategory?.name ?? ''}  ${_selectedModel?.name ?? ''} 단가표',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _PriceGrid(
                  cells: _cells,
                  inference: _inference,
                  hasSize: _hasSize,
                  won: _won,
                  onSetSize: (w, h) {
                    _writeSize(widthMm: w, heightMm: h);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _quoteLine => formatStandardQuoteLine(
        categoryName: _selectedCategory?.name ?? '',
        modelName: _selectedModel?.name ?? '',
        inference: _inference,
      );

  List<SameSizeModelQuote> get _comparisons {
    if (!_hasSize) return const [];
    final catalog = _catalog;
    final catId = _categoryId;
    if (catalog == null || catId == null) return const [];
    return sameSizeQuotes(
      models: catalog
          .modelsFor(catId)
          .map((m) => (id: m.id, name: m.name, color: m.color))
          .toList(),
      cellsByModel: {
        for (final e in _cellsByModel.entries)
          e.key: e.value.map((c) => c.asCell).toList(),
      },
      widthMm: _widthMm,
      heightMm: _heightMm,
      ceilingHeights: _isGarageDoor,
    );
  }

  Future<void> _copyQuote({bool share = false}) async {
    if (!_hasSize) return;
    final line = _quoteLine;
    await Clipboard.setData(ClipboardData(text: line));
    if (!mounted) return;
    if (share) {
      await SharePlus.instance.share(ShareParams(text: line));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('단가를 복사했습니다')),
    );
  }

  Future<void> _reloadHistory() async {
    final adjustments = await _repo.fetchAdjustments(limit: 200);
    final logs = await _repo.fetchChangeLogs(limit: 500);
    if (!mounted) return;
    setState(() {
      _adjustments = adjustments;
      _logs = logs;
    });
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(koreanErrorMessage(e))),
    );
  }

  int get _widthMm =>
      int.tryParse(_widthCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  int get _heightMm =>
      int.tryParse(_heightCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  bool get _hasSize => _widthMm > 0 && _heightMm > 0;

  bool get _isGarageDoor => _selectedCategory?.name == '차고문';

  StandardPriceInference get _inference => inferStandardPrice(
        cells: _cells.map((c) => c.asCell).toList(),
        widthMm: _widthMm == 0 ? 2000 : _widthMm,
        heightMm: _heightMm == 0 ? 2000 : _heightMm,
        ceilingHeights: _isGarageDoor,
      );

  StandardUnitPriceModel? get _selectedModel {
    final id = _modelId;
    if (id == null) return null;
    for (final m in _catalog?.models ?? const <StandardUnitPriceModel>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  StandardUnitPriceCategory? get _selectedCategory {
    final id = _categoryId;
    if (id == null) return null;
    for (final c in _catalog?.categories ?? const <StandardUnitPriceCategory>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _applyAdjust() async {
    final user = ref.read(authControllerProvider);
    if (!canEditStandardUnitPrice(user)) return;
    final modelId = _modelId;
    if (modelId == null) return;
    final value = num.tryParse(_adjustValueCtrl.text.replaceAll(',', ''));
    if (value == null || value == 0) {
      final typedInReason = num.tryParse(_adjustReasonCtrl.text.replaceAll(',', ''));
      _showError(StateError(
        typedInReason != null && typedInReason != 0
            ? '조정액 칸에 $typedInReason을 넣고, 사유 칸에는 이유를 적어 주세요.'
            : '조정액 칸에 0이 아닌 값을 입력해 주세요. 인하는 -100처럼 앞에 마이너스를 붙입니다.',
      ));
      return;
    }
    if (_adjustReasonCtrl.text.trim().isEmpty) {
      _showError(StateError('조정 사유를 입력해 주세요.'));
      return;
    }
    final label = _adjustType == StandardAdjustType.percent
        ? '$value%'
        : '${_won.format(value)}원';
    final action = value < 0 ? '인하' : '인상';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일괄 조정'),
        content: Text(
          '${_selectedModel?.name ?? '선택한 모델'} 단가를 $label $action할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repo.applyAdjustment(
        modelId: modelId,
        type: _adjustType,
        value: value,
        reason: _adjustReasonCtrl.text,
        userId: user?.id ?? '',
        userName: user?.name ?? '관리자',
      );
      _adjustReasonCtrl.clear();
      await _reloadCells(modelId);
      await _reloadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일괄 조정을 적용했습니다')),
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory(String name) async {
    if (!canEditStandardUnitPrice(ref.read(authControllerProvider))) return;
    setState(() => _saving = true);
    try {
      final used = [
        ...?_catalog?.categories.map((c) => c.color),
        ...?_catalog?.models.map((m) => m.color),
      ];
      await _repo.addCategory(name, color: nextStandardColor(used));
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameCategory(StandardUnitPriceCategory cat, String name) async {
    setState(() => _saving = true);
    try {
      await _repo.updateCategory(id: cat.id, name: name);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCategory(StandardUnitPriceCategory cat) async {
    final childCount =
        _catalog?.models.where((m) => m.categoryId == cat.id).length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 삭제'),
        content: Text(
          '「${cat.name}」 분류를 삭제할까요?\n하위 모델 $childCount개와 단가표가 함께 삭제됩니다.',
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
    setState(() => _saving = true);
    try {
      await _repo.deleteCategory(cat.id);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addModel(String categoryId, String name) async {
    setState(() => _saving = true);
    try {
      final used = [
        ...?_catalog?.categories.map((c) => c.color),
        ...?_catalog?.models.map((m) => m.color),
      ];
      await _repo.addModel(
        categoryId: categoryId,
        name: name,
        color: nextStandardColor(used),
      );
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameModel(StandardUnitPriceModel model, String name) async {
    setState(() => _saving = true);
    try {
      await _repo.updateModel(id: model.id, name: name);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteModel(StandardUnitPriceModel model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모델 삭제'),
        content: Text('「${model.name}」 모델을 삭제할까요?\n이 모델의 단가표도 함께 삭제됩니다.'),
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
    setState(() => _saving = true);
    try {
      await _repo.deleteModel(model.id);
      await _load();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final editable = canEditStandardUnitPrice(user);

    return Scaffold(
      appBar: AppBar(
        title: widget.showAppBar ? const Text('표준단가') : null,
        toolbarHeight: widget.showAppBar ? kToolbarHeight : 44,
        automaticallyImplyLeading: widget.showAppBar,
        actions: [
          IconButton(
            tooltip: '홍보 이미지',
            onPressed: _loading || _error != null || _catalog == null
                ? null
                : () => unawaited(_openPromoImages()),
            icon: const Icon(Icons.collections_outlined),
          ),
          IconButton(
            tooltip: '단가표',
            onPressed: _loading || _error != null ? null : _openGridSheet,
            icon: const Icon(Icons.grid_on_rounded),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              HapticFeedback.selectionClick();
              unawaited(_load());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: (value) {
              if (_catalog == null) return;
              switch (value) {
                case 'adjust':
                  _openTool(
                    '일괄 조정',
                    _AdjustTab(
                      modelName: _selectedModel?.name ?? '-',
                      type: _adjustType,
                      valueCtrl: _adjustValueCtrl,
                      reasonCtrl: _adjustReasonCtrl,
                      cells: _cells,
                      editable: editable,
                      saving: _saving,
                      onType: (t) => setState(() => _adjustType = t),
                      onApply: _applyAdjust,
                    ),
                  );
                case 'history':
                  _openTool(
                    '변경 이력',
                    _HistoryTab(
                      adjustments: _adjustments,
                      logs: _logs,
                      openId: _openAdjustmentId,
                      won: _won,
                      dt: _dt,
                      onToggle: (id) => setState(
                        () => _openAdjustmentId =
                            _openAdjustmentId == id ? null : id,
                      ),
                    ),
                  );
                case 'catalog':
                  _openTool(
                    '분류/모델',
                    _CatalogTab(
                      catalog: _catalog!,
                      editable: editable,
                      saving: _saving,
                      onAddCategory: _addCategory,
                      onRenameCategory: _renameCategory,
                      onDeleteCategory: _deleteCategory,
                      onAddModel: _addModel,
                      onRenameModel: _renameModel,
                      onDeleteModel: _deleteModel,
                    ),
                  );
                case 'export':
                  unawaited(_exportExcel());
                case 'quotes':
                  unawaited(_openQuoteHistory());
                case 'promo':
                  unawaited(_openPromoImages());
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'quotes', child: Text('견적 기록')),
              const PopupMenuItem(value: 'promo', child: Text('홍보 이미지')),
              if (editable)
                const PopupMenuItem(value: 'adjust', child: Text('일괄 조정')),
              const PopupMenuItem(value: 'history', child: Text('변경 이력')),
              if (editable)
                const PopupMenuItem(value: 'catalog', child: Text('분류/모델')),
              const PopupMenuItem(value: 'export', child: Text('엑셀(CSV) 저장')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: '표준단가 불러오는 중…')
          : _error != null
              ? AppErrorState(
                  message: koreanErrorMessage(_error!),
                  onRetry: _load,
                )
              : _LookupTab(
                  catalog: _catalog!,
                  categoryId: _categoryId,
                  modelId: _modelId,
                  comparisons: _comparisons,
                  widthMm: _widthMm,
                  heightMm: _heightMm,
                  editingWidth: _editingWidth,
                  inference: _inference,
                  hasSize: _hasSize,
                  selectedCategory: _selectedCategory,
                  selectedModel: _selectedModel,
                  won: _won,
                  onSelectCategory: _selectCategory,
                  onSelectModel: _selectModel,
                  onEditWidth: _setEditingWidth,
                  onTapSizeAxis: _tapSizeAxis,
                  onQuickWidth: _quickWidth,
                  onQuickHeight: _quickHeight,
                  onDigit: _appendDigit,
                  onBackspace: _backspaceSize,
                  onClearCurrent: _clearCurrentAxis,
                  onClearAll: () {
                    _widthCtrl.clear();
                    _heightCtrl.clear();
                    setState(() => _editingWidth = true);
                    _persistLookup();
                  },
                  onCopyPrice: () => unawaited(_copyQuote()),
                  onSharePrice: () => unawaited(_copyQuote(share: true)),
                  onShowGrid: _openGridSheet,
                  similarCount: _similarQuotes.length,
                  onWriteQuote: () => unawaited(_openQuoteWriter()),
                  onOpenSimilar: _similarQuotes.isEmpty
                      ? null
                      : () => unawaited(_openSimilarQuotes()),
                ),
    );
  }
}

class _LookupTab extends StatelessWidget {
  const _LookupTab({
    required this.catalog,
    required this.categoryId,
    required this.modelId,
    required this.comparisons,
    required this.widthMm,
    required this.heightMm,
    required this.editingWidth,
    required this.inference,
    required this.hasSize,
    required this.selectedCategory,
    required this.selectedModel,
    required this.won,
    required this.onSelectCategory,
    required this.onSelectModel,
    required this.onEditWidth,
    required this.onTapSizeAxis,
    required this.onQuickWidth,
    required this.onQuickHeight,
    required this.onDigit,
    required this.onBackspace,
    required this.onClearCurrent,
    required this.onClearAll,
    required this.onCopyPrice,
    required this.onSharePrice,
    required this.onShowGrid,
    required this.similarCount,
    required this.onWriteQuote,
    this.onOpenSimilar,
  });

  final StandardUnitPriceCatalog catalog;
  final String? categoryId;
  final String? modelId;
  final List<SameSizeModelQuote> comparisons;
  final int widthMm;
  final int heightMm;
  final bool editingWidth;
  final StandardPriceInference inference;
  final bool hasSize;
  final StandardUnitPriceCategory? selectedCategory;
  final StandardUnitPriceModel? selectedModel;
  final NumberFormat won;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onSelectModel;
  final ValueChanged<bool> onEditWidth;
  final ValueChanged<bool> onTapSizeAxis;
  final ValueChanged<int> onQuickWidth;
  final ValueChanged<int> onQuickHeight;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClearCurrent;
  final VoidCallback onClearAll;
  final VoidCallback onCopyPrice;
  final VoidCallback onSharePrice;
  final VoidCallback onShowGrid;
  final int similarCount;
  final VoidCallback onWriteQuote;
  final VoidCallback? onOpenSimilar;


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final models = categoryId == null
        ? const <StandardUnitPriceModel>[]
        : catalog.modelsFor(categoryId!);
    final price = hasSize ? (inference.estimatedPrice ?? 0) : 0;
    final unavailable = hasSize &&
        (inference.outOfRange ||
            (!inference.isEstimated &&
                inference.match?.available == false &&
                (inference.isExactBucket || price <= 0)));
    final accent = hexToColor(
      selectedModel?.color ?? selectedCategory?.color ?? '#334155',
    );
    final headerColor = unavailable
        ? scheme.error
        : hasSize && inference.isEstimated
            ? const Color(0xFFB45309)
            : accent;
    final heightChips = selectedCategory?.name == '차고문'
        ? garageQuickHeights
        : standardQuickHeights;
    SameSizeModelQuote? quoteOf(String id) {
      for (final q in comparisons) {
        if (q.modelId == id) return q;
      }
      return null;
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        _PriceHeader(
          color: headerColor,
          hasSize: hasSize,
          unavailable: unavailable,
          price: price,
          inference: inference,
          won: won,
          onCopyPrice: onCopyPrice,
          onSharePrice: onSharePrice,
          onShowGrid: onShowGrid,
          onWriteQuote: onWriteQuote,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: _CategoryTabs(
            categories: catalog.orderedCategories,
            selectedId: categoryId,
            onSelect: onSelectCategory,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              itemCount: models.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final model = models[i];
                return _ModelTile(
                  name: model.name,
                  color: hexToColor(model.color),
                  selected: model.id == modelId,
                  quote: quoteOf(model.id),
                  hasSize: hasSize,
                  won: won,
                  onTap: () => onSelectModel(model.id),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: _SizeTapCard(
                  caption: '폭',
                  value: widthMm > 0 ? won.format(widthMm) : '·····',
                  color: const Color(0xFF1D4ED8),
                  selected: editingWidth,
                  onTap: () => onTapSizeAxis(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '×',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
              Expanded(
                flex: 6,
                child: _SizeTapCard(
                  caption: '높이',
                  value: heightMm > 0 ? won.format(heightMm) : '·····',
                  color: const Color(0xFF0F766E),
                  selected: !editingWidth,
                  onTap: () => onTapSizeAxis(false),
                ),
              ),
              IconButton(
                tooltip: '사이즈 지움',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: widthMm > 0 || heightMm > 0 ? onClearAll : null,
                icon: const Icon(Icons.backspace_outlined, size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 12, 4 + bottomInset),
            child: Column(
              children: [
                if (similarCount > 0 && onOpenSimilar != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.history_rounded, size: 16),
                        label: Text('비슷한 사이즈 견적 $similarCount건'),
                        onPressed: onOpenSimilar,
                      ),
                    ),
                  ),
                _LabeledChipRow(
                  label: editingWidth ? '폭' : '높이',
                  color: editingWidth
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF0F766E),
                  children: [
                    for (final mm
                        in editingWidth ? standardQuickWidths : heightChips)
                      _ChoicePill(
                        label: mm == 2150
                            ? '2150 4단'
                            : mm == 2700
                                ? '2700 5단'
                                : '$mm',
                        selected: editingWidth
                            ? widthMm == mm
                            : heightMm == mm,
                        color: editingWidth
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF0F766E),
                        onTap: () => editingWidth
                            ? onQuickWidth(mm)
                            : onQuickHeight(mm),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _InlineKeypad(
                    editingWidth: editingWidth,
                    canCopy: hasSize && !unavailable && price > 0,
                    onDigit: onDigit,
                    onBackspace: onBackspace,
                    onClear: onClearCurrent,
                    onToggleAxis: () => onEditWidth(!editingWidth),
                    onCopy: onCopyPrice,
                    onWriteQuote: onWriteQuote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _PriceHeader extends StatefulWidget {
  const _PriceHeader({
    required this.color,
    required this.hasSize,
    required this.unavailable,
    required this.price,
    required this.inference,
    required this.won,
    required this.onCopyPrice,
    required this.onSharePrice,
    required this.onShowGrid,
    required this.onWriteQuote,
  });

  final Color color;
  final bool hasSize;
  final bool unavailable;
  final int price;
  final StandardPriceInference inference;
  final NumberFormat won;
  final VoidCallback onCopyPrice;
  final VoidCallback onSharePrice;
  final VoidCallback onShowGrid;
  final VoidCallback onWriteQuote;

  @override
  State<_PriceHeader> createState() => _PriceHeaderState();
}

class _PriceHeaderState extends State<_PriceHeader> {
  bool _open = false;

  String get _amountText {
    if (!widget.hasSize) return '모델 고르고 폭·높이를 넣으세요';
    if (widget.unavailable) return '해당 사이즈 불가';
    if (widget.price > 0) return '${widget.won.format(widget.price)}원';
    return '단가 없음';
  }

  @override
  Widget build(BuildContext context) {
    final canCopy =
        widget.hasSize && !widget.unavailable && widget.price > 0;
    return Material(
      color: widget.color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.hasSize && widget.inference.isEstimated)
                  const _HeaderTag(
                    label: '추정',
                    bg: Color(0xFFFDE68A),
                    fg: Color(0xFF78350F),
                  ),
                if (widget.hasSize && widget.inference.outOfRange)
                  const _HeaderTag(
                    label: '초과',
                    bg: Color(0xFFFECACA),
                    fg: Color(0xFF7F1D1D),
                  ),
                if (widget.hasSize &&
                    (widget.inference.isEstimated ||
                        widget.inference.outOfRange))
                  const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: canCopy ? widget.onCopyPrice : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _amountText,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
                if (canCopy)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: FilledButton(
                      onPressed: widget.onWriteQuote,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: widget.color,
                        minimumSize: const Size(56, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('견적서'),
                    ),
                  ),
                TextButton(
                  onPressed: () => setState(() => _open = !_open),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(_open ? '접기' : '펴기'),
                ),
                IconButton(
                  tooltip: '단가표',
                  onPressed: widget.onShowGrid,
                  color: Colors.white,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.grid_on_rounded),
                ),
              ],
            ),
            if (_open) ...[
              if (canCopy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    koreanWonInWords(widget.price),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
              if (widget.hasSize)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Text(
                    describeSizeLookup(widget.inference),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.25,
                    ),
                  ),
                ),
              if (canCopy)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onSharePrice,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('공유'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  const _HeaderTag({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.name,
    required this.color,
    required this.selected,
    required this.quote,
    required this.hasSize,
    required this.won,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final SameSizeModelQuote? quote;
  final bool hasSize;
  final NumberFormat won;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priceText = !hasSize
        ? '선택'
        : (quote == null || quote!.unavailable)
            ? '불가'
            : '${won.format(quote!.price)}원';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: Material(
        color: selected ? color : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    priceText,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.95)
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledChipRow extends StatelessWidget {
  const _LabeledChipRow({
    required this.label,
    required this.color,
    required this.children,
  });

  final String label;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        Expanded(child: _ChoiceChipRow(children: children)),
      ],
    );
  }
}

class _InlineKeypad extends StatelessWidget {
  const _InlineKeypad({
    required this.editingWidth,
    required this.canCopy,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onToggleAxis,
    required this.onCopy,
    required this.onWriteQuote,
  });

  final bool editingWidth;
  final bool canCopy;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onToggleAxis;
  final VoidCallback onCopy;
  final VoidCallback onWriteQuote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', '←'],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final actionH = constraints.maxHeight < 220
            ? 36.0
            : constraints.maxHeight < 280
                ? 40.0
                : 44.0;
        final gap = constraints.maxHeight < 220 ? 2.0 : 4.0;
        final digitSize = constraints.maxHeight < 220 ? 20.0 : 24.0;

        Widget keyBtn(String key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: FilledButton.tonal(
                onPressed: () {
                  if (key == '←') {
                    onBackspace();
                  } else {
                    onDigit(key);
                  }
                },
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurface,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: digitSize,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final row in rows)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final key in row) keyBtn(key)],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: gap),
            SizedBox(
              height: actionH,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: editingWidth
                          ? onClear
                          : (canCopy ? onCopy : onClear),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(0, actionH),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          editingWidth
                              ? '폭 지움'
                              : (canCopy ? '복사' : '높이 지움'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      onPressed: editingWidth
                          ? onToggleAxis
                          : (canCopy ? onWriteQuote : onToggleAxis),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, actionH),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          editingWidth
                              ? '다음 · 높이'
                              : (canCopy ? '견적서' : '폭으로'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PriceGrid extends StatelessWidget {
  const _PriceGrid({
    required this.cells,
    required this.inference,
    required this.hasSize,
    required this.won,
    required this.onSetSize,
  });

  final List<StandardUnitPriceRow> cells;
  final StandardPriceInference inference;
  final bool hasSize;
  final NumberFormat won;
  final void Function(int widthMm, int heightMm) onSetSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axes = gridAxesFromCells(cells.map((c) => c.asCell));
    final highlightKeys = {
      for (final cell in inference.highlightCells) cell.key,
    };
    String heightLabel(int size) {
      if (size == 2150) return '2150 4단';
      if (size == 2700) return '2700 5단';
      return '$size';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const pad = 12.0;
        const minAxis = 64.0;
        const minData = 52.0;
        const minHead = 36.0;
        const minCell = 40.0;
        final availW = constraints.maxWidth - pad * 2;
        final dataCols = axes.widths.length;
        final minTableW = minAxis + minData * dataCols;
        final fillW = dataCols > 0 && minTableW <= availW;
        final axisW = fillW ? (availW * 0.24).clamp(64.0, 92.0) : minAxis;
        final dataW = dataCols == 0
            ? minData
            : fillW
                ? (availW - axisW) / dataCols
                : minData;
        final headH = minHead;
        final cellH = fillW ? 56.0 : minCell;
        final table = Table(
          border: TableBorder.all(color: scheme.outlineVariant),
          columnWidths: {
            0: FixedColumnWidth(axisW),
            for (var i = 0; i < dataCols; i++)
              i + 1: FixedColumnWidth(dataW),
          },
          children: [
            TableRow(
              children: [
                _GridCorner(height: headH),
                for (final w in axes.widths)
                  _GridHead(caption: '폭', value: '$w', height: headH),
              ],
            ),
            for (final h in axes.heights)
              TableRow(
                children: [
                  _GridAxisCell(
                    caption: '높이',
                    value: heightLabel(h),
                    height: cellH,
                  ),
                  for (final w in axes.widths)
                    _LookupGridCell(
                      cell: _lookupCell(cells, w, h),
                      selected: hasSize &&
                          !inference.isEstimated &&
                          !inference.outOfRange &&
                          inference.bucketWidth == w &&
                          inference.bucketHeight == h,
                      highlighted: hasSize &&
                          highlightKeys.contains('${w}_$h'),
                      outOfRange: hasSize && inference.outOfRange,
                      estimated: hasSize && inference.isEstimated,
                      height: cellH,
                      large: fillW,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSetSize(w, h);
                      },
                    ),
                ],
              ),
          ],
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(pad, 0, pad, 16),
            child: table,
          ),
        );
      },
    );
  }
}


StandardUnitPriceRow? _lookupCell(
  List<StandardUnitPriceRow> cells,
  int width,
  int height,
) {
  for (final cell in cells) {
    if (cell.widthMm == width && cell.heightMm == height) return cell;
  }
  return null;
}

class _ChoiceChipRow extends StatelessWidget {
  const _ChoiceChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    // 세로 Wrap은 키패드 높이를 밀어 overflow를 낸다. 한 줄 가로 스크롤로 고정.
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => children[i],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<StandardUnitPriceCategory> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (categories.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          for (final cat in categories)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(cat.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: cat.id == selectedId
                        ? hexToColor(cat.color)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    cat.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: cat.id == selectedId
                          ? Colors.white
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? color
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeTapCard extends StatelessWidget {
  const _SizeTapCard({
    required this.caption,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String caption;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placeholder = value.contains('·');
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.35),
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      placeholder ? value : '$value mm',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: placeholder ? 1.2 : 0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCorner extends StatelessWidget {
  const _GridCorner({this.height = 36});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF334155),
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            '높이↓\n폭→',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridHead extends StatelessWidget {
  const _GridHead({
    required this.caption,
    required this.value,
    this.height = 36,
  });
  final String caption;
  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1D4ED8),
      child: SizedBox(
        height: height,
        child: Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$caption\n',
                  style: const TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    height: 1.05,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    height: 1.05,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _GridAxisCell extends StatelessWidget {
  const _GridAxisCell({
    required this.caption,
    required this.value,
    this.height = 40,
  });
  final String caption;
  final String value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFCCFBF1),
      child: SizedBox(
        height: height,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$caption\n',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      height: 1.05,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: Color(0xFF134E4A),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _LookupGridCell extends StatelessWidget {
  const _LookupGridCell({
    required this.cell,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
    this.outOfRange = false,
    this.estimated = false,
    this.height = 40,
    this.large = false,
  });

  final StandardUnitPriceRow? cell;
  final bool selected;
  final bool highlighted;
  final bool outOfRange;
  final bool estimated;
  final VoidCallback onTap;
  final double height;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final blocked = cell != null && !cell!.available;
    final priced = cell != null && !blocked && cell!.price > 0;
    final label = blocked
        ? 'X'
        : priced
            ? '${(cell!.price / 10000).round()}만'
            : '-';
    final ring = selected
        ? const Color(0xFF0F172A)
        : highlighted
            ? (outOfRange ? const Color(0xFFDC2626) : const Color(0xFFFBBF24))
            : null;
    return Material(
      color: blocked
          ? const Color(0xFF7F1D1D)
          : selected
              ? const Color(0xFFFFF7ED)
              : highlighted && estimated
                  ? const Color(0xFFFEF3C7)
                  : highlighted && outOfRange
                      ? const Color(0xFFFEE2E2)
                      : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: ring == null
              ? const BoxDecoration()
              : BoxDecoration(
                  border: Border.all(color: ring, width: 2),
                ),
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: large ? 18 : 11,
                  fontWeight: FontWeight.w900,
                  color: blocked
                      ? Colors.white
                      : selected
                          ? const Color(0xFF9A3412)
                          : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustTab extends StatefulWidget {
  const _AdjustTab({
    required this.modelName,
    required this.type,
    required this.valueCtrl,
    required this.reasonCtrl,
    required this.cells,
    required this.editable,
    required this.saving,
    required this.onType,
    required this.onApply,
  });

  final String modelName;
  final StandardAdjustType type;
  final TextEditingController valueCtrl;
  final TextEditingController reasonCtrl;
  final List<StandardUnitPriceRow> cells;
  final bool editable;
  final bool saving;
  final ValueChanged<StandardAdjustType> onType;
  final VoidCallback onApply;

  @override
  State<_AdjustTab> createState() => _AdjustTabState();
}

class _AdjustTabState extends State<_AdjustTab> {
  @override
  void initState() {
    super.initState();
    widget.valueCtrl.addListener(_onValue);
  }

  @override
  void didUpdateWidget(covariant _AdjustTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueCtrl != widget.valueCtrl) {
      oldWidget.valueCtrl.removeListener(_onValue);
      widget.valueCtrl.addListener(_onValue);
    }
  }

  @override
  void dispose() {
    widget.valueCtrl.removeListener(_onValue);
    super.dispose();
  }

  void _onValue() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value =
        num.tryParse(widget.valueCtrl.text.replaceAll(',', '')) ?? 0;
    final preview = widget.cells
        .where(
          (c) =>
              c.available &&
              applyPriceAdjustment(
                    oldPrice: c.price,
                    type: widget.type,
                    value: value,
                  ) !=
                  c.price,
        )
        .length;
    final amountWords = widget.type == StandardAdjustType.amount
        ? koreanWonInWords(value.round())
        : '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          '선택한 모델(${widget.modelName})의 단가 있는 칸만 바꿉니다. 플러스는 인상, 마이너스(-10% · -100,000원)는 인하입니다. 불가(X)·0원 칸은 그대로 두고, 없는 사이즈는 만들지 않습니다.',
        ),
        const SizedBox(height: 12),
        SegmentedButton<StandardAdjustType>(
          segments: const [
            ButtonSegment(
              value: StandardAdjustType.percent,
              label: Text('% 조정'),
            ),
            ButtonSegment(
              value: StandardAdjustType.amount,
              label: Text('금액 조정'),
            ),
          ],
          selected: {widget.type},
          onSelectionChanged: (s) => widget.onType(s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.valueCtrl,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          inputFormatters: widget.type == StandardAdjustType.amount
              ? const [ThousandsFormatter(signed: true)]
              : const [],
          onTap: () => widget.valueCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: widget.valueCtrl.text.length,
          ),
          decoration: InputDecoration(
            labelText: widget.type == StandardAdjustType.percent
                ? '조정률(%)'
                : '조정액(원)',
            hintText: widget.type == StandardAdjustType.percent
                ? '예: 5 또는 -5'
                : '예: -100',
            helperText: widget.type == StandardAdjustType.amount
                ? (amountWords.isEmpty
                    ? '인하는 -100처럼 이 칸에 입력하세요'
                    : amountWords)
                : (value == 0
                    ? '인상은 양수, 인하는 음수입니다. 이 칸에 입력하세요'
                    : '$value% ${value < 0 ? '인하' : '인상'}'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.reasonCtrl,
          decoration: const InputDecoration(
            labelText: '사유',
            hintText: '예: 원자재 인상 / 프로모션 인하',
          ),
        ),
        const SizedBox(height: 12),
        Text('변경 예정 칸: $preview개'),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: !widget.editable || widget.saving ? null : widget.onApply,
          child: const Text('모델 단가 일괄 적용'),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({
    required this.adjustments,
    required this.logs,
    required this.openId,
    required this.won,
    required this.dt,
    required this.onToggle,
  });

  final List<StandardUnitPriceAdjustment> adjustments;
  final List<StandardUnitPriceChangeLog> logs;
  final String? openId;
  final NumberFormat won;
  final DateFormat dt;
  final ValueChanged<String> onToggle;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  bool _yearly = false;
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final adjustments = widget.adjustments;
    final logs = widget.logs;
    final won = widget.won;
    final dt = widget.dt;
    final logTuples = logs
        .map(
          (l) => (
            adjustmentId: l.adjustmentId,
            widthMm: l.widthMm,
            heightMm: l.heightMm,
            oldPrice: l.oldPrice,
            newPrice: l.newPrice,
          ),
        )
        .toList();
    String editorOf(StandardUnitPriceAdjustment row) {
      final name = row.userName.trim();
      return name.isEmpty ? '알 수 없음' : name;
    }

    String labelOf(StandardUnitPriceAdjustment row) {
      final base = describeStandardAdjustment(
        type: row.adjustmentType,
        value: row.adjustmentValue,
        cells: row.cellsAffected,
        id: row.id,
        logs: logTuples,
      );
      if (row.adjustmentType != 'manual' && row.cellsAffected > 1) {
        return '$base (${row.cellsAffected}칸)';
      }
      return base;
    }

    String labelWithEditor(StandardUnitPriceAdjustment row) =>
        '${labelOf(row)} · ${editorOf(row)}';

    var raiseCount = 0;
    var cutCount = 0;
    for (final row in adjustments) {
      if (row.adjustmentType == 'manual') {
        final delta = logs
            .where((l) => l.adjustmentId == row.id)
            .fold<int>(0, (s, l) => s + (l.newPrice - l.oldPrice));
        if (delta > 0) raiseCount += 1;
        if (delta < 0) cutCount += 1;
      } else if (row.adjustmentValue > 0) {
        raiseCount += 1;
      } else if (row.adjustmentValue < 0) {
        cutCount += 1;
      }
    }
    final periodMap = <String, List<String>>{};
    final periodEditors = <String, List<String>>{};
    final byUser = <String, int>{};
    for (final row in adjustments) {
      final q = seoulYearQuarter(row.createdAt);
      final key = _yearly ? '${q.year}년' : '${q.year}년 ${q.quarter}분기';
      periodMap.putIfAbsent(key, () => []).add(labelWithEditor(row));
      final editors = periodEditors.putIfAbsent(key, () => []);
      final editor = editorOf(row);
      if (!editors.contains(editor)) editors.add(editor);
      byUser[editor] = (byUser[editor] ?? 0) + 1;
    }
    final periodKeys = periodMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final lastLabel =
        adjustments.isEmpty ? '-' : labelWithEditor(adjustments.first);
    final userNames = byUser.keys.toList()
      ..sort((a, b) => (byUser[b] ?? 0).compareTo(byUser[a] ?? 0));
    if (adjustments.isEmpty && logs.isEmpty) {
      return const AppEmpty(
        message: '아직 단가 변경 이력이 없습니다. 수정하면 연도별·분기별 통계가 쌓입니다.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('단가 변동 통계', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('분기별')),
            ButtonSegment(value: true, label: Text('연도별')),
          ],
          selected: {_yearly},
          onSelectionChanged: (s) => setState(() => _yearly = s.first),
        ),
        const SizedBox(height: 10),
        Text('조정 ${adjustments.length}회 · 인상 $raiseCount · 인하 $cutCount'),
        Text(
          '최근 적용 $lastLabel',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (adjustments.isNotEmpty)
          Text(
            '최근 수정 ${editorOf(adjustments.first)} · ${dt.format(adjustments.first.createdAt.toLocal())}',
          ),
        const SizedBox(height: 8),
        for (final key in periodKeys)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(key, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${periodMap[key]!.length}회 · ${periodMap[key]!.join(' · ')}\n수정한 사람: ${(periodEditors[key] ?? const []).join(', ')}',
            ),
          ),
        if (userNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('수정한 사람', style: TextStyle(fontWeight: FontWeight.w800)),
          for (final name in userNames)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text('${byUser[name]}회'),
            ),
        ],
        const SizedBox(height: 16),
        const Text('변경이 어떻게 이뤄졌는지', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final row in adjustments) ...[
          Card(
            child: InkWell(
              onTap: () => setState(
                () => _openId = _openId == row.id ? null : row.id,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if ((row.categoryName ?? '').isNotEmpty) row.categoryName,
                        row.modelName ?? '모델',
                      ].join(' / '),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${labelOf(row)}'
                      '${row.adjustmentType != 'manual' && row.cellsAffected > 1 ? ' · ${row.cellsAffected}칸에 각각 적용' : ''}',
                    ),
                    Text(
                      '수정한 사람: ${row.userName.trim().isEmpty ? '알 수 없음' : row.userName}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text('사유: ${row.reason}'),
                    Text(
                      dt.format(row.createdAt.toLocal()),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_openId == row.id) ...[
                      const Divider(),
                      for (final log in logs.where((l) => l.adjustmentId == row.id))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${log.widthMm}×${log.heightMm}${log.userName.trim().isEmpty ? '' : ' · ${log.userName}'}  ${won.format(log.oldPrice)} → ${won.format(log.newPrice)}',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('칸별 변화 흐름', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final log in logs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${log.modelName ?? '-'}  ${log.widthMm}×${log.heightMm}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${dt.format(log.createdAt.toLocal())} · ${log.reason} · ${log.userName}',
            ),
            trailing: Text(
              '${won.format(log.oldPrice)}→${won.format(log.newPrice)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({
    required this.catalog,
    required this.editable,
    required this.saving,
    required this.onAddCategory,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    required this.onAddModel,
    required this.onRenameModel,
    required this.onDeleteModel,
  });

  final StandardUnitPriceCatalog catalog;
  final bool editable;
  final bool saving;
  final ValueChanged<String> onAddCategory;
  final void Function(StandardUnitPriceCategory cat, String name)
      onRenameCategory;
  final ValueChanged<StandardUnitPriceCategory> onDeleteCategory;
  final void Function(String categoryId, String name) onAddModel;
  final void Function(StandardUnitPriceModel model, String name) onRenameModel;
  final ValueChanged<StandardUnitPriceModel> onDeleteModel;

  Future<String?> _prompt(BuildContext context, String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '이름'),
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
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (!editable) {
      return const AppEmpty(
        message: '분류·모델 수정은 표준단가 수정 권한이 필요합니다.',
        icon: Icons.lock_outline_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text(
          'standard_unit_price_categories / standard_unit_price_models',
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: saving
              ? null
              : () async {
                  final name = await _prompt(context, '큰 분류 추가', '');
                  if (name != null && name.isNotEmpty) onAddCategory(name);
                },
          child: const Text('큰 분류 추가'),
        ),
        const SizedBox(height: 12),
        for (final cat in catalog.categories) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: hexToColor(cat.color), radius: 8),
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '모델 ${catalog.modelsFor(cat.id).length}개',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: '수정',
                  onPressed: saving
                      ? null
                      : () async {
                          final name = await _prompt(context, '분류 수정', cat.name);
                          if (name != null && name.isNotEmpty) {
                            onRenameCategory(cat, name);
                          }
                        },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: '삭제',
                  onPressed: saving ? null : () => onDeleteCategory(cat),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          for (final model in catalog.modelsFor(cat.id))
            ListTile(
              contentPadding: const EdgeInsets.only(left: 12),
              leading: CircleAvatar(backgroundColor: hexToColor(model.color), radius: 7),
              title: Text(model.name),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: '수정',
                    onPressed: saving
                        ? null
                        : () async {
                            final name =
                                await _prompt(context, '모델 수정', model.name);
                            if (name != null && name.isNotEmpty) {
                              onRenameModel(model, name);
                            }
                          },
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: '삭제',
                    onPressed: saving ? null : () => onDeleteModel(model),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final name = await _prompt(context, '모델 추가 · ${cat.name}', '');
                      if (name != null && name.isNotEmpty) {
                        onAddModel(cat.id, name);
                      }
                    },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('모델 추가'),
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }
}
