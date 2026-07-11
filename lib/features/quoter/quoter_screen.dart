import 'dart:async';
import 'dart:convert';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_company_models.dart';
import 'package:coad_customer_calls/features/quoter/quoter_formatters.dart';
import 'package:coad_customer_calls/features/quoter/quoter_providers.dart';
import 'package:coad_customer_calls/features/quoter/quoter_type_style.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/features/quoter/similar_estimates_notifier.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_out_of_table_warning.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_type_selector.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_wizard_header.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class QuoterScreen extends ConsumerStatefulWidget {
  const QuoterScreen({super.key, this.showQuickActions = true});

  final bool showQuickActions;

  @override
  ConsumerState<QuoterScreen> createState() => _QuoterScreenState();
}

class _QuoterScreenState extends ConsumerState<QuoterScreen> {
  int _currentStep = 1;
  bool _isCostSettingsExpanded = false;
  bool _isCalculating = false;
  bool _quickActionsOpen = false;
  DateTime? _lastPriceSyncAt;
  bool _priceUpdateAvailable = false;
  final NumberFormat _krwFormat = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );

  // -- State --
  ShutterType _selectedType = ShutterType.doubleExtrusion;
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final FocusNode _widthFocusNode = FocusNode();
  final FocusNode _heightFocusNode = FocusNode();

  // 비용 직접 수정용 컨트롤러
  final _motorCostController = TextEditingController(text: '400,000');
  final _installCostController = TextEditingController(text: '600,000');
  final _equipCostController = TextEditingController(text: '200,000');
  final _bendingCostController = TextEditingController(text: '500,000');
  final _profitCostController = TextEditingController(text: '800,000');

  ShutterEstimateResult? _result;
  ShutterEstimateInput? _similarLookupInput;
  final Set<String> _simulatedMotorIds = {};
  Map<String, List<Map<String, dynamic>>>? _latestPrices;
  String? _selectedCompanyId;
  List<CompanyComparisonRow> _companyComparisons = const [];

  bool get _canCalculate {
    final w = double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0;
    final h = double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0;
    return w > 0 && h > 0;
  }

  bool get _hasAnyInput {
    return _widthController.text.trim().isNotEmpty ||
        _heightController.text.trim().isNotEmpty ||
        _result != null;
  }

  bool get _isOutOfTableSizeRange {
    final w = double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0;
    final h = double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0;
    if (w <= 0 || h <= 0) return false;
    return w < ShutterCalculator.minBucket ||
        w > ShutterCalculator.maxBucket ||
        h < ShutterCalculator.minBucket ||
        h > ShutterCalculator.maxBucket;
  }


  @override
  void initState() {
    super.initState();
    _widthController.addListener(_invalidateCalculatedResult);
    _heightController.addListener(_invalidateCalculatedResult);
    _motorCostController.addListener(_invalidateCalculatedResult);
    _installCostController.addListener(_invalidateCalculatedResult);
    _equipCostController.addListener(_invalidateCalculatedResult);
    _bendingCostController.addListener(_invalidateCalculatedResult);
    _profitCostController.addListener(_invalidateCalculatedResult);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedSyncTime();
      _checkIfPriceRefreshNeeded();
    });
  }

  @override
  void dispose() {
    _widthController.removeListener(_invalidateCalculatedResult);
    _heightController.removeListener(_invalidateCalculatedResult);
    _motorCostController.removeListener(_invalidateCalculatedResult);
    _installCostController.removeListener(_invalidateCalculatedResult);
    _equipCostController.removeListener(_invalidateCalculatedResult);
    _bendingCostController.removeListener(_invalidateCalculatedResult);
    _profitCostController.removeListener(_invalidateCalculatedResult);
    _widthController.dispose();
    _heightController.dispose();
    _widthFocusNode.dispose();
    _heightFocusNode.dispose();
    _motorCostController.dispose();
    _installCostController.dispose();
    _equipCostController.dispose();
    _bendingCostController.dispose();
    _profitCostController.dispose();
    super.dispose();
  }

  void _invalidateCalculatedResult() {
    if (_result == null || _isCalculating) return;
    final editingDimensionNow =
        _currentStep == 2 &&
        (_widthFocusNode.hasFocus || _heightFocusNode.hasFocus);
    if (editingDimensionNow) {
      // Avoid immediate rebuild while IME is composing text. Rebuild can
      // momentarily hide composing characters on some Android keyboards.
      _result = null;
      _similarLookupInput = null;
      _companyComparisons = const [];
      return;
    }
    setState(() {
      _result = null;
      _similarLookupInput = null;
      _companyComparisons = const [];
    });
  }

  void _resetToDefaults() {
    setState(() {
      _motorCostController.text = '400,000';
      _installCostController.text = '600,000';
      _equipCostController.text = '200,000';
      _bendingCostController.text = '500,000';
      _profitCostController.text = '800,000';
    });
  }

  void _newEstimate() {
    setState(() {
      _selectedType = ShutterType.doubleExtrusion;
      _widthController.clear();
      _heightController.clear();
      _result = null;
      _similarLookupInput = null;
      _simulatedMotorIds.clear();
      _selectedCompanyId = null;
      _companyComparisons = const [];
      _resetToDefaults();
      _currentStep = 1;
    });
  }

  void _onDimensionChanged(String _) {
    _invalidateCalculatedResult();
  }

  Future<void> _goToStep(int step) async {
    if (step == _currentStep) return;
    setState(() {
      _currentStep = step;
      if (step == 3) _isCostSettingsExpanded = true;
    });
    if (step == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_widthFocusNode);
      });
    }
    if (step == 4 && _canCalculate && !_isCalculating) {
      await _calculate();
    }
  }

  Future<void> _calculate() async {
    if (_isCalculating) return;
    FocusScope.of(context).unfocus();
    final w = double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0;
    final h = double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0;
    if (w <= 0 || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('폭과 높이를 올바르게 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCalculating = true);
    try {
      final prices = await ref.read(shutterPricesFutureProvider.future);
      _latestPrices = prices;
      final input = _buildEstimateInput(w: w, h: h);
      final companyContext = _buildCompanyContext(
        prices: prices,
        selectedCompanyId: _selectedCompanyId,
      );
      _debugLogCompanyRows(
        rawRows: prices['company'] ?? const [],
        parsedRows: companyContext.companies,
      );
      final selectedCompany = companyContext.selectedCompany;
      final unitMap = selectedCompany == null
          ? null
          : ShutterCalculator.unitPriceMapFromCompany(
              selectedCompany.toJson(),
              companyContext.fallbackUnitPriceMap,
            );
      final res = ShutterCalculator.calculate(
        input: input,
        gridPrices: prices['grid'] as List<Map<String, dynamic>>,
        unitPrices: prices['unit'] as List<Map<String, dynamic>>,
        unitPriceOverrideMap: unitMap,
      );
      final comparisons = _buildCompanyComparisons(
        prices: prices,
        input: input,
        selectedCompanyId: companyContext.selectedCompanyId,
      );

      if (!mounted) return;

      setState(() {
        _result = res;
        _similarLookupInput = ShutterEstimateInput(
          type: _selectedType,
          widthMm: w,
          heightMm: h,
        );
        _currentStep = 4;
        _selectedCompanyId = companyContext.selectedCompanyId;
        _companyComparisons = comparisons;
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('견적이 산출되었습니다.'),
              ],
            ),
            backgroundColor: Colors.teal.shade600,
            duration: const Duration(seconds: 2),
          ),
        );

      // Web과 동일: 견적 확정 직후 1회 fire-and-forget 로그 전송 (실패해도 UI 영향 없음)
      final currentUser = ref.read(authControllerProvider);
      final userId = currentUser?.id.trim() ?? '';
      final userName = currentUser?.name.trim() ?? '';
      if (userId.isNotEmpty && userName.isNotEmpty) {
        unawaited(
          ref
              .read(shutterRepositoryProvider)
              .logEstimate({
                'user_id': userId,
                'user_name': userName,
                'width_mm': input.widthMm.toInt(),
                'height_mm': input.heightMm.toInt(),
                // 웹과 동일한 모델 문자열 사용
                'model_type': QuoterTypeStyle.label(_selectedType),
                // JSON number로 전송되도록 숫자 타입 유지
                'total_price': res.totalAmount,
                'created_at': DateTime.now().toIso8601String(),
              })
              .catchError((e) => debugPrint('Logging failed: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계산 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  ShutterEstimateInput _buildEstimateInput({
    required double w,
    required double h,
  }) {
    return ShutterEstimateInput(
      type: _selectedType,
      widthMm: w,
      heightMm: h,
      includeInstallation: true,
      includeMotor: true,
      includeProfit: true,
      overrideMotorCost: int.tryParse(
        _motorCostController.text.replaceAll(',', ''),
      ),
      overrideInstallCost: int.tryParse(
        _installCostController.text.replaceAll(',', ''),
      ),
      overrideEquipCost: int.tryParse(
        _equipCostController.text.replaceAll(',', ''),
      ),
      overrideBendingCost: int.tryParse(
        _bendingCostController.text.replaceAll(',', ''),
      ),
      overrideProfitCost: int.tryParse(
        _profitCostController.text.replaceAll(',', ''),
      ),
    );
  }

  CompanyContext _buildCompanyContext({
    required Map<String, List<Map<String, dynamic>>> prices,
    required String? selectedCompanyId,
  }) {
    final companies = _parseCompanyRows(prices['company'] ?? const []);
    final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
      prices['unit'] as List<Map<String, dynamic>>,
    );
    if (!ShutterCalculator.isSecurityType(_selectedType) || companies.isEmpty) {
      return CompanyContext(
        companies: companies,
        selectedCompanyId: null,
        selectedCompany: null,
        fallbackUnitPriceMap: fallbackMap,
      );
    }

    ShutterCompanyUnitPrice? selected;
    ShutterCompanyUnitPrice? defaultCompany;
    for (final company in companies) {
      if (company.id == selectedCompanyId) {
        selected = company;
      }
      if (defaultCompany == null && company.isDefault) {
        defaultCompany = company;
      }
    }
    final resolved = selected ?? defaultCompany ?? companies.first;
    return CompanyContext(
      companies: companies,
      selectedCompanyId: resolved.id,
      selectedCompany: resolved,
      fallbackUnitPriceMap: fallbackMap,
    );
  }

  List<CompanyComparisonRow> _buildCompanyComparisons({
    required Map<String, List<Map<String, dynamic>>> prices,
    required ShutterEstimateInput input,
    required String? selectedCompanyId,
  }) {
    if (!ShutterCalculator.isSecurityType(_selectedType)) return const [];
    final companies = _parseCompanyRows(prices['company'] ?? const []);
    if (companies.isEmpty) return const [];

    final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
      prices['unit'] as List<Map<String, dynamic>>,
    );
    final rows = companies.map((company) {
      final unitMap = ShutterCalculator.unitPriceMapFromCompany(
        company.toJson(),
        fallbackMap,
      );
      final estimate = ShutterCalculator.calculate(
        input: input,
        gridPrices: prices['grid'] as List<Map<String, dynamic>>,
        unitPrices: prices['unit'] as List<Map<String, dynamic>>,
        unitPriceOverrideMap: unitMap,
      );
      return CompanyComparisonRow(
        company: company,
        totalAmount: estimate.totalAmount,
        slatAmount: ShutterCalculator.extractSlatPrice(estimate),
      );
    }).toList();
    int? selectedTotal;
    for (final row in rows) {
      if (row.company.id == selectedCompanyId) {
        selectedTotal = row.totalAmount;
        break;
      }
    }
    return rows
        .map(
          (row) => row.copyWith(
            deltaFromSelected: selectedTotal == null
                ? 0
                : row.totalAmount - selectedTotal,
          ),
        )
        .toList();
  }

  List<ShutterCompanyUnitPrice> _parseCompanyRows(
    List<Map<String, dynamic>> rawRows,
  ) {
    final rows = rawRows
        .asMap()
        .entries
        .map(
          (entry) => ShutterCompanyUnitPrice.fromJson(
            entry.value,
            fallbackId: 'company_${entry.key}',
          ),
        )
        .toList();
    rows.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return a.companyName.compareTo(b.companyName);
    });
    return rows;
  }

  void _debugLogCompanyRows({
    required List<Map<String, dynamic>> rawRows,
    required List<ShutterCompanyUnitPrice> parsedRows,
  }) {
    if (!kDebugMode) return;
    final rawNames = rawRows
        .map((e) => (e['company_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    final parsedNames = parsedRows.map((e) => e.companyName).join(', ');
    print('[ShutterCompany] rawCount=${rawRows.length} rawNames=[$rawNames]');
    print(
      '[ShutterCompany] parsedCount=${parsedRows.length} parsedNames=[$parsedNames]',
    );
  }

  Future<void> _onSelectCompany(String companyId) async {
    final prices = _latestPrices;
    if (prices == null || _isCalculating) return;
    final w = double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0;
    final h = double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0;
    if (w <= 0 || h <= 0 || _result == null) return;

    final input = _buildEstimateInput(w: w, h: h);
    final companyContext = _buildCompanyContext(
      prices: prices,
      selectedCompanyId: companyId,
    );
    final selectedCompany = companyContext.selectedCompany;
    final unitMap = selectedCompany == null
        ? null
        : ShutterCalculator.unitPriceMapFromCompany(
            selectedCompany.toJson(),
            companyContext.fallbackUnitPriceMap,
          );
    final updatedResult = ShutterCalculator.calculate(
      input: input,
      gridPrices: prices['grid'] as List<Map<String, dynamic>>,
      unitPrices: prices['unit'] as List<Map<String, dynamic>>,
      unitPriceOverrideMap: unitMap,
    );
    final comparisons = _buildCompanyComparisons(
      prices: prices,
      input: input,
      selectedCompanyId: companyContext.selectedCompanyId,
    );

    setState(() {
      _result = updatedResult;
      _selectedCompanyId = companyContext.selectedCompanyId;
      _companyComparisons = comparisons;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pricesAsync = ref.watch(shutterPricesFutureProvider);

    return Material(
      color: scheme.surface,
      child: pricesAsync.when(
        data: (_) {
          if (_lastPriceSyncAt == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _lastPriceSyncAt != null) return;
              setState(() => _lastPriceSyncAt = DateTime.now());
            });
          }
          return widget.showQuickActions
              ? _buildWithQuickActions(scheme, _buildContent(scheme))
              : _buildContent(scheme);
        },
        loading: () => widget.showQuickActions
            ? _buildWithQuickActions(
                scheme,
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: scheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        '단가 데이터 로딩 중...',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      '단가 데이터 로딩 중...',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
        error: (e, stack) => widget.showQuickActions
            ? _buildWithQuickActions(
                scheme,
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: scheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '데이터 로딩 실패',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(shutterPricesFutureProvider),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '데이터 로딩 실패',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: scheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(shutterPricesFutureProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWithQuickActions(ColorScheme scheme, Widget content) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 16.0 + safeBottom;
    final quickActions = <_QuoterQuickActionItem>[
      _QuoterQuickActionItem(
        label: '홈',
        color: Colors.blueGrey.shade700,
        icon: Icons.home_rounded,
        onTap: () async {
          openHomeHub(context, ref);
        },
      ),
      _QuoterQuickActionItem(
        label: '접수',
        color: scheme.tertiary,
        icon: Icons.add_ic_call_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: kSalesCallCreateRouteName),
              builder: (_) => const SalesCallCreateScreen(),
            ),
          );
        },
      ),
      _QuoterQuickActionItem(
        label: '발행요청',
        color: Colors.indigo.shade600,
        icon: Icons.receipt_long_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const IssuanceRequestScreen(),
            ),
          );
        },
      ),
    ];

    return Stack(
      children: [
        content,
        if (_quickActionsOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _quickActionsOpen = false),
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(
          right: 16,
          bottom: actionsBottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_quickActionsOpen)
                Container(
                  width: 182,
                  constraints: const BoxConstraints(maxHeight: 300),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: quickActions
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Material(
                                color: item.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    setState(() => _quickActionsOpen = false);
                                    await item.onTap();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 18,
                                          color: item.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              FloatingActionButton(
                heroTag: 'quoter_open_menu',
                mini: true,
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                tooltip: _quickActionsOpen ? '닫기' : '열기',
                onPressed: () =>
                    setState(() => _quickActionsOpen = !_quickActionsOpen),
                child: Icon(
                  _quickActionsOpen
                      ? Icons.close_rounded
                      : Icons.menu_open_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    const bottomPad = 16.0;
    final accent = quoterStepAccent(_currentStep);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelTint = accent.withValues(alpha: isDark ? 0.12 : 0.085);
    final panelBorder = accent.withValues(alpha: isDark ? 0.52 : 0.34);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad),
      child: Column(
        children: [
          _buildPriceSyncBar(scheme),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(panelTint, scheme.surface),
                  border: Border.all(color: panelBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.72)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Column(
                          children: [
                            _buildWizardHeader(scheme),
                            const SizedBox(height: 8),
                            _buildWizardActions(scheme),
                            const SizedBox(height: 10),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _buildStepBody(scheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime value) {
    return DateFormat('MM/dd HH:mm').format(value);
  }

  Future<void> _refreshPricesManually() async {
    final prefs = ref.read(appDependenciesProvider).prefs;
    // 1회성 강제 갱신: 캐시 삭제 후 invalidate (sticky forceNetwork 없음)
    await clearShutterPriceCache(prefs);
    ref.invalidate(shutterPricesFutureProvider);
    try {
      await ref.read(shutterPricesFutureProvider.future);
      if (!mounted) return;
      setState(() {
        _lastPriceSyncAt = DateTime.now();
        _priceUpdateAvailable = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('단가를 최신값으로 갱신했습니다.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('단가 새로고침에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadCachedSyncTime() async {
    final prefs = ref.read(appDependenciesProvider).prefs;
    final cachedAt = prefs.getString(StorageKeys.shutterPriceCachedAt);
    if (cachedAt == null || cachedAt.trim().isEmpty || !mounted) return;
    final parsed = DateTime.tryParse(cachedAt);
    if (parsed == null) return;
    setState(() => _lastPriceSyncAt = parsed.toLocal());
  }

  Future<void> _checkIfPriceRefreshNeeded() async {
    try {
      final prefs = ref.read(appDependenciesProvider).prefs;
      final cachedGrid = prefs.getString(StorageKeys.shutterPriceGridCache);
      final cachedUnit = prefs.getString(StorageKeys.shutterPriceUnitCache);
      if (cachedGrid == null || cachedUnit == null) return;

      final repo = ref.read(shutterRepositoryProvider);
      final remoteGrid = await repo.fetchGridPrices();
      final remoteUnit = await repo.fetchUnitPrices();
      final remoteGridJson = jsonEncode(remoteGrid);
      final remoteUnitJson = jsonEncode(remoteUnit);
      if (!mounted) return;
      setState(
        () => _priceUpdateAvailable =
            remoteGridJson != cachedGrid || remoteUnitJson != cachedUnit,
      );
    } catch (_) {
      // 네트워크 실패 시에는 조용히 무시 (캐시 사용 지속)
    }
  }

  Widget _buildPriceSyncBar(ColorScheme scheme) {
    final syncText = _lastPriceSyncAt == null
        ? '단가 갱신 정보 없음'
        : '단가 갱신: ${_formatSyncTime(_lastPriceSyncAt!)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              syncText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_priceUpdateAvailable)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                '새 단가 있음',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          Tooltip(
            message: '단가 새로고침',
            child: OutlinedButton(
              onPressed: _refreshPricesManually,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(36, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              child: const Icon(Icons.refresh_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWizardHeader(ColorScheme scheme) {
    return QuoterWizardHeader(
      currentStep: _currentStep,
      hasResult: _result != null,
      onStepTap: (step) => unawaited(_goToStep(step)),
    );
  }

  Widget _buildStepBody(ColorScheme scheme) {
    switch (_currentStep) {
      case 1:
        return SingleChildScrollView(
          key: const ValueKey('step1'),
          child: _buildTypeSelector(scheme),
        );
      case 2:
        return SingleChildScrollView(
          key: const ValueKey('step2'),
          child: _buildSizeInput(scheme),
        );
      case 3:
        return LayoutBuilder(
          key: const ValueKey('step3'),
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildCostSettings(scheme),
            ),
          ),
        );
      case 4:
      default:
        final a4 = quoterStepAccent(4);
        return Container(
          key: const ValueKey('step4'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.insights_rounded, size: 18, color: a4),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '4단계 · 최종 견적',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: a4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _result == null
                  ? _buildCalculateButton(scheme)
                  : _buildStep4ResultTopBar(scheme),
              if (_selectedType == ShutterType.fireSteel ||
                  _selectedType == ShutterType.fireScreen)
                _buildSimilarEstimatesSection(scheme),
              const SizedBox(height: 10),
              Expanded(
                child: _result == null
                    ? _buildStep4Placeholder(scheme)
                    : _buildResultCompactCard(scheme),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildStep4Placeholder(ColorScheme scheme) {
    final a = quoterStepAccent(4);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_rounded, size: 42, color: a),
            const SizedBox(height: 10),
            Text(
              '최종 견적 산출',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: a,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '상단 버튼을 눌러 현재 조건으로 견적을 계산하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardActions(ColorScheme scheme) {
    final canNext = _currentStep < 4;
    final canPrev = _currentStep > 1;

    bool nextEnabled() {
      if (_currentStep == 2) return _canCalculate;
      return canNext;
    }

    final navAccent = quoterStepAccent(_currentStep);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          navAccent.withValues(alpha: isDark ? 0.10 : 0.06),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: navAccent.withValues(alpha: isDark ? 0.38 : 0.26),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          children: [
            if (_hasAnyInput)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _newEstimate();
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('다시 견적내기'),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canPrev
                        ? () {
                            HapticFeedback.lightImpact();
                            _goToStep(_currentStep - 1);
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                    ),
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !nextEnabled()
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            // 2단계(규격)에서는 비용(3단계)을 건너뛰고 바로 4단계(결과)로 이동
                            final nextStep = _currentStep == 2
                                ? 4
                                : (_currentStep < 4 ? _currentStep + 1 : null);
                            if (nextStep != null) await _goToStep(nextStep);
                          },
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: navAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(_currentStep == 2 ? '견적 산출' : '다음'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme scheme) {
    return QuoterTypeSelector(
      selectedType: _selectedType,
      onSelected: (t) {
        setState(() => _selectedType = t);
        _invalidateCalculatedResult();
        if (_currentStep == 1) {
          unawaited(_goToStep(2));
        }
      },
    );
  }

  // ─────────────────────────────────────────────────
  // 규격 입력
  // ─────────────────────────────────────────────────
  Widget _buildSizeInput(ColorScheme scheme) {
    final a = quoterStepAccent(2);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _widthController,
      builder: (_, __, ___) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _heightController,
          builder: (_, __, ___) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: a.withValues(alpha: 0.42),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: a.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 360;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.straighten_rounded,
                                size: 18,
                                color: a,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '2단계 · 규격 입력 (mm)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: a,
                                  ),
                                ),
                              ),
                              if (!compact && _result != null)
                                TextButton.icon(
                                  onPressed: _newEstimate,
                                  icon: const Icon(
                                    Icons.restart_alt_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    '초기화',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: scheme.error,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (compact && _result != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _newEstimate,
                                icon: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  '초기화',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.error,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSizeField(
                    label: '폭 (W)',
                    controller: _widthController,
                    scheme: scheme,
                    hint: '3000',
                    focusNode: _widthFocusNode,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_heightFocusNode),
                  ),
                  const SizedBox(height: 12),
                  _buildSizeField(
                    label: '높이 (H)',
                    controller: _heightController,
                    scheme: scheme,
                    hint: '3000',
                    focusNode: _heightFocusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 10),
                  _buildDimensionLivePanel(scheme),
                  if (_isOutOfTableSizeRange) ...[
                    const SizedBox(height: 12),
                    const QuoterOutOfTableWarning(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSizeField({
    required String label,
    required TextEditingController controller,
    required ColorScheme scheme,
    String? hint,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: textInputAction,
                scrollPadding: const EdgeInsets.only(bottom: 180),
                // Numeric keyboard is enough here; hard filtering can hide
                // composing text on some Android keyboards while typing.
                inputFormatters: const [],
                onChanged: _onDimensionChanged,
                onSubmitted: onSubmitted,
                autocorrect: false,
                enableSuggestions: false,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.25,
                ),
                strutStyle: const StrutStyle(
                  fontSize: 22,
                  height: 1.25,
                  forceStrutHeight: true,
                ),
                cursorColor: scheme.primary,
                textAlign: TextAlign.left,
                textAlignVertical: TextAlignVertical.center,
                maxLines: 1,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary, width: 1.8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'mm',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDimensionLivePanel(ColorScheme scheme) {
    String pretty(TextEditingController controller) {
      final value = int.tryParse(controller.text.replaceAll(',', '')) ?? 0;
      return value > 0 ? '${NumberFormat('#,###').format(value)} mm' : '입력 대기';
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _widthController,
      builder: (_, __, ___) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _heightController,
          builder: (_, __, ___) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '폭: ${pretty(_widthController)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '높이: ${pretty(_heightController)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────
  // 비용 설정 (접이식)
  // ─────────────────────────────────────────────────
  Widget _buildCostSettings(ColorScheme scheme) {
    final a = quoterStepAccent(3);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: a.withValues(alpha: 0.42), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: a.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (탭해서 펼치기)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                () => _isCostSettingsExpanded = !_isCostSettingsExpanded,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, size: 18, color: a),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '3단계 · 비용 설정',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: a,
                          ),
                        ),
                        Text(
                          _isCostSettingsExpanded ? '탭하여 접기' : '탭하여 상세 비용 조정',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: _isCostSettingsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 펼쳐지는 내용
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildCostFields(scheme),
            crossFadeState: _isCostSettingsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildCostFields(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildSettingsField(
                  label: '모터가격',
                  icon: Icons.settings_remote_rounded,
                  controller: _motorCostController,
                  scheme: scheme,
                ),
                const Divider(height: 1),
                _buildSettingsField(
                  label: '시공비',
                  icon: Icons.construction_rounded,
                  controller: _installCostController,
                  scheme: scheme,
                ),
                const Divider(height: 1),
                _buildSettingsField(
                  label: '장비대',
                  icon: Icons.precision_manufacturing_rounded,
                  controller: _equipCostController,
                  scheme: scheme,
                ),
                const Divider(height: 1),
                _buildSettingsField(
                  label: '절곡비용',
                  icon: Icons.architecture_rounded,
                  controller: _bendingCostController,
                  scheme: scheme,
                ),
                const Divider(height: 1),
                _buildSettingsField(
                  label: '당사이익',
                  icon: Icons.trending_up_rounded,
                  controller: _profitCostController,
                  scheme: scheme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetToDefaults,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('기본값으로 초기화', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: scheme.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required ColorScheme scheme,
  }) {
    // 5만 원 단위 조정 함수
    void adjustPrice(int delta) {
      final currentText = controller.text.replaceAll(',', '');
      final currentValue = int.tryParse(currentText) ?? 0;
      final newValue = (currentValue + delta).clamp(0, 99999999);
      final formatted = NumberFormat('#,###').format(newValue);
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      HapticFeedback.lightImpact();
      // 즉시 계산 반영을 원할 수도 있지만, 여기서는 UI 업데이트만 수행
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdjustButton(
                icon: Icons.remove_rounded,
                onPressed: () => adjustPrice(-50000),
                scheme: scheme,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    const ThousandsFormatter(),
                  ],
                  onChanged: (_) => _invalidateCalculatedResult(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: scheme.primary, width: 1.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '원',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              _buildAdjustButton(
                icon: Icons.add_rounded,
                onPressed: () => adjustPrice(50000),
                scheme: scheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, size: 16, color: scheme.primary),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 견적 산출 버튼
  // ─────────────────────────────────────────────────
  Widget _buildCalculateButton(ColorScheme scheme) {
    final typeColor = QuoterTypeStyle.color(_selectedType);
    final enabled = _canCalculate && !_isCalculating;
    return GestureDetector(
      onTap: enabled ? _calculate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: !enabled
              ? LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                )
              : LinearGradient(
                  colors: [typeColor, scheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: !enabled
              ? []
              : [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.40),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCalculating)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.calculate_rounded,
                color: Colors.white,
                size: 24,
              ),
            const SizedBox(width: 12),
            Text(
              _isCalculating
                  ? '4단계 · 산출 중...'
                  : enabled
                  ? '4단계 · 최종 견적 산출'
                  : '폭/높이 입력 후 견적 산출',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4ResultTopBar(ColorScheme scheme) {
    final typeColor = QuoterTypeStyle.color(_selectedType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '최종 견적 결과',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _isCalculating ? null : _calculate,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('다시 산출'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 결과 카드
  // ─────────────────────────────────────────────────
  Widget _buildResultCard(ColorScheme scheme) {
    final typeColor = QuoterTypeStyle.color(_selectedType);

    int slatTotal = 0;
    int installTotal = 0;
    for (final item in _result!.breakdown) {
      if (item.name.contains('스라트')) {
        slatTotal += item.amount;
      } else if (item.name == '시공 예상 비용') {
        installTotal = item.amount;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: typeColor.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 총액 헤더 ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              gradient: LinearGradient(
                colors: [
                  typeColor.withValues(alpha: 0.08),
                  typeColor.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 320;
                    return Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: compact ? 6 : 0,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            QuoterTypeStyle.label(_selectedType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: typeColor,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: compact ? constraints.maxWidth : null,
                          child: Text(
                            _result!.calculatedAt,
                            textAlign: compact
                                ? TextAlign.right
                                : TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _copyEstimateToClipboard,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('견적 복사'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '최종 견적 금액',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaPill(
                      label: '셔터 종류',
                      value: QuoterTypeStyle.label(_selectedType),
                      scheme: scheme,
                    ),
                    _buildMetaPill(
                      label: '규격',
                      value:
                          '${_widthController.text} × ${_heightController.text} mm',
                      scheme: scheme,
                    ),
                  ],
                ),
                if (_isOutOfTableSizeRange) ...[
                  const SizedBox(height: 10),
                  const QuoterOutOfTableWarning(),
                ],
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _krwFormat.format(_result!.totalAmount),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: typeColor,
                      letterSpacing: -1.5,
                    ),
                  ),
                ),
                if (ShutterCalculator.isSecurityType(_selectedType) &&
                    _result != null &&
                    _canCalculate &&
                    _companyComparisons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildCompanyComparisonCard(scheme),
                ],
                const SizedBox(height: 16),
                // 요약 칩
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildSummaryChip(
                      label: '스라트',
                      amount: slatTotal,
                      color: Colors.blue.shade600,
                      scheme: scheme,
                      note: _result!.slatPriceNote,
                    ),
                    _buildSummaryChip(
                      label: '시공비',
                      amount: installTotal,
                      color: Colors.orange.shade700,
                      scheme: scheme,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showBreakdownSheet(scheme),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: Text('견적 상세 (${_result!.breakdown.length})'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSpecsSheet(scheme),
                    icon: const Icon(Icons.memory_rounded, size: 16),
                    label: const Text('기술 사양'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCompactCard(ColorScheme scheme) {
    final result = _result!;
    final typeColor = QuoterTypeStyle.color(_selectedType);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showResultActionSheet(scheme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surface,
          border: Border.all(color: typeColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: typeColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '현재 총액',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _krwFormat.format(result.totalAmount),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    letterSpacing: -1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultActionSheet(ColorScheme scheme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final breakdownCount = _result?.breakdown.length ?? 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text('견적 상세 ($breakdownCount)'),
                  subtitle: const Text('자재/모터 · 시공/부대 · 기타'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showBreakdownSheet(scheme);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.memory_rounded),
                  title: const Text('기술 사양'),
                  subtitle: const Text('권장 모터 · 소비전력 · 셔터박스 · 브라켓'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showSpecsSheet(scheme);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _compactItemName(String raw) {
    return raw
        .replaceAll(' 예상 ', ' ')
        .replaceAll(' 비용', '')
        .replaceAll('기본 견적', '기본')
        .replaceAll('당사 이익', '이익');
  }

  Widget _buildGroupedBreakdown(ColorScheme scheme) {
    final groups = _groupBreakdownItems();
    final keys = groups.keys.toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: keys.asMap().entries.map((entry) {
          final idx = entry.key;
          final key = entry.value;
          final items = groups[key]!;
          final subtotal = items.fold<int>(
            0,
            (int sum, ShutterBreakdownItem e) => sum + e.amount,
          );
          final isLastGroup = idx == keys.length - 1;

          return Container(
            decoration: BoxDecoration(
              border: isLastGroup
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.22),
                      ),
                    ),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: idx == 0
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.zero,
                  ),
                  child: Row(
                    children: [
                      if (key == '자재/모터') ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '스라트/모터',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _krwFormat.format(subtotal),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.asMap().entries.map((line) {
                  final lineIdx = line.key;
                  final item = line.value;
                  final isLastLine = lineIdx == items.length - 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: isLastLine
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                      borderRadius: isLastGroup && isLastLine
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            )
                          : BorderRadius.zero,
                    ),
                    child: Row(
                      children: [
                        if (key == '자재/모터') ...[
                          _buildMaterialTypeBadge(item, scheme),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            _compactItemName(item.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _krwFormat.format(item.amount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, List<ShutterBreakdownItem>> _groupBreakdownItems() {
    final result = <String, List<ShutterBreakdownItem>>{
      '자재/모터': [],
      '시공/부대': [],
      '기타': [],
    };

    for (final item in _result!.breakdown) {
      final n = item.name.toLowerCase();
      if (n.contains('스라트') || n.contains('모터') || n.contains('기본')) {
        result['자재/모터']!.add(item);
      } else if (n.contains('시공') || n.contains('장비') || n.contains('절곡')) {
        result['시공/부대']!.add(item);
      } else {
        result['기타']!.add(item);
      }
    }

    // 비어 있는 그룹은 제거해 카드 길이를 줄인다.
    result.removeWhere((_, v) => v.isEmpty);
    return result;
  }

  Widget _buildMaterialTypeBadge(
    ShutterBreakdownItem item,
    ColorScheme scheme,
  ) {
    final n = item.name.toLowerCase();
    String label = '자재';
    Color bg = scheme.primaryContainer.withValues(alpha: 0.65);
    Color fg = scheme.primary;
    if (n.contains('모터')) {
      label = '모터';
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange.shade800;
    } else if (n.contains('스라트')) {
      label = '스라트';
      bg = Colors.blue.withValues(alpha: 0.15);
      fg = Colors.blue.shade800;
    } else if (n.contains('기본')) {
      label = '기본';
      bg = Colors.teal.withValues(alpha: 0.14);
      fg = Colors.teal.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildOpenSheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme scheme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showSpecsSheet(ColorScheme scheme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSectionTitle('기술 사양', Icons.memory_rounded, scheme),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildSpecItem(
                            '추정 무게',
                            '${_result!.weightKg.toStringAsFixed(1)} kg',
                            scheme,
                          ),
                          _buildSpecItem('권장 모터', _result!.motorModel, scheme),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          _buildSpecItem('소비전력', _result!.powerSpec, scheme),
                          _buildSpecItem('셔터박스', _result!.boxSize, scheme),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          _buildSpecItem(
                            '브라켓 종류',
                            _result!.bracketType,
                            scheme,
                          ),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBreakdownSheet(ColorScheme scheme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_companyComparisons.isNotEmpty) ...[
                    _buildCompanyDeltaSummaryCard(scheme),
                    const SizedBox(height: 12),
                  ],
                  _buildGroupedBreakdown(scheme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyEstimateToClipboard() async {
    final r = _result;
    if (r == null) return;
    final width = _widthController.text.trim().isEmpty
        ? '-'
        : _widthController.text.trim();
    final height = _heightController.text.trim().isEmpty
        ? '-'
        : _heightController.text.trim();
    final sb = StringBuffer();
    sb.writeln('[셔터 견적서]');
    sb.writeln('셔터 종류: ${QuoterTypeStyle.label(_selectedType)}');
    sb.writeln('규격(mm): $width x $height');
    sb.writeln('브라켓 종류: ${r.bracketType}');
    sb.writeln('총액: ${_krwFormat.format(r.totalAmount)}');
    sb.writeln('산출시각: ${r.calculatedAt}');
    sb.writeln('');
    sb.writeln('[상세]');
    for (final item in r.breakdown) {
      sb.writeln(
        '- ${_compactItemName(item.name)}: ${_krwFormat.format(item.amount)}',
      );
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('견적 내용이 복사되었습니다.')));
  }

  Widget _buildMetaPill({
    required String label,
    required String value,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: scheme.onSurface, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ColorScheme scheme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required int amount,
    required Color color,
    required ColorScheme scheme,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,###').format(amount)}원',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyComparisonCard(ColorScheme scheme) {
    if (_companyComparisons.isEmpty) {
      return const SizedBox.shrink();
    }
    final sorted = [..._companyComparisons]
      ..sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
    final minRow = sorted.first;
    CompanyComparisonRow? selectedRow;
    for (final row in _companyComparisons) {
      if (row.company.id == _selectedCompanyId) {
        selectedRow = row;
        break;
      }
    }
    final savingFromSelected = selectedRow == null
        ? 0
        : (selectedRow.totalAmount - minRow.totalAmount).clamp(0, 1 << 30);
    final isMinAlreadySelected = selectedRow?.company.id == minRow.company.id;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '제조사별 가격 (스라트 변경)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: isMinAlreadySelected
                    ? null
                    : () => _onSelectCompany(minRow.company.id),
                icon: const Icon(Icons.trending_down_rounded, size: 16),
                label: const Text('최소값 적용'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isMinAlreadySelected
                ? '현재 최저가 업체가 적용중입니다 (${minRow.company.companyName})'
                : '최저가: ${minRow.company.companyName} · 현재 대비 -${NumberFormat('#,###').format(savingFromSelected)}원',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _companyComparisons)
            _buildCompanyComparisonRow(scheme: scheme, row: row),
          const SizedBox(height: 8),
          Text(
            '관리자에 등록된 회사 ㎡ 단가(일반·단열)로 스라트만 바꾼 금액입니다. 모터·시공비·부대비용은 동일합니다.',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyComparisonRow({
    required ColorScheme scheme,
    required CompanyComparisonRow row,
  }) {
    final isSelected = row.company.id == _selectedCompanyId;
    final delta = row.deltaFromSelected;
    final deltaText = delta == 0
        ? '±0원'
        : '${delta > 0 ? '+' : '-'}${NumberFormat('#,###').format(delta.abs())}원';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.22)
            : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onSelectCompany(row.company.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? scheme.primary.withValues(alpha: 0.55)
                    : scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              row.company.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '적용중',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '총액 ${_krwFormat.format(row.totalAmount)} · 스라트 ${_krwFormat.format(row.slatAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  deltaText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: delta == 0
                        ? scheme.onSurfaceVariant
                        : (delta > 0
                              ? Colors.red.shade700
                              : Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDeltaSummaryCard(ColorScheme scheme) {
    CompanyComparisonRow? selectedRow;
    for (final row in _companyComparisons) {
      if (row.company.id == _selectedCompanyId) {
        selectedRow = row;
        break;
      }
    }
    final selectedName = selectedRow?.company.companyName ?? '기본 단가';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '업체 비교 요약',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '적용 업체: $selectedName',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _companyComparisons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.company.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: row.company.id == _selectedCompanyId
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row.deltaFromSelected == 0
                        ? '기준'
                        : '${row.deltaFromSelected > 0 ? '+' : '-'}${NumberFormat('#,###').format(row.deltaFromSelected.abs())}원',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: row.deltaFromSelected == 0
                          ? scheme.onSurfaceVariant
                          : (row.deltaFromSelected > 0
                                ? Colors.red.shade700
                                : Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, ColorScheme scheme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 비슷한 사이즈 리스트
  // ─────────────────────────────────────────────────
  Widget _buildSimilarEstimatesSection(ColorScheme scheme) {
    if (_selectedType != ShutterType.fireSteel &&
        _selectedType != ShutterType.fireScreen) {
      return const SizedBox.shrink();
    }

    final tempInput = _similarLookupInput;
    if (tempInput == null) return const SizedBox.shrink();
    final similarAsync = ref.watch(similarEstimatesProvider(tempInput));

    return similarAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        final withMotor = list.where((e) => e.estimate.hasMotor).toList();
        final withoutMotor = list.where((e) => !e.estimate.hasMotor).toList();

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: scheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '비슷한 사이즈 이전 견적',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () =>
                        ref.invalidate(similarEstimatesProvider(tempInput)),
                    tooltip: '새로고침',
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (withMotor.isNotEmpty)
                _buildSimilarGroupCard(
                  '모터 포함',
                  withMotor,
                  scheme,
                  isMotorIncluded: true,
                ),
              if (withMotor.isNotEmpty && withoutMotor.isNotEmpty)
                const SizedBox(height: 10),
              if (withoutMotor.isNotEmpty)
                _buildSimilarGroupCard(
                  '모터 미포함',
                  withoutMotor,
                  scheme,
                  isMotorIncluded: false,
                ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '유사 데이터 로딩 실패: $e',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildSimilarGroupCard(
    String title,
    List<ScoredEstimate> items,
    ColorScheme scheme, {
    required bool isMotorIncluded,
  }) {
    final headerColor = isMotorIncluded
        ? Colors.teal.shade700
        : Colors.orange.shade700;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: headerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(
                bottom: BorderSide(color: headerColor.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMotorIncluded
                      ? Icons.settings_remote_rounded
                      : Icons.handyman_rounded,
                  size: 14,
                  color: headerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: headerColor,
                  ),
                ),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final se = entry.value;
            final est = se.estimate;
            final isSimulated = _simulatedMotorIds.contains(est.id);
            final displayAmount = isSimulated
                ? est.amount + 400000
                : est.amount;
            final isLast = idx == items.length - 1;

            return InkWell(
              onTap: () {},
              borderRadius: isLast
                  ? const BorderRadius.vertical(bottom: Radius.circular(18))
                  : BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${est.width.round()}×${est.height.round()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _krwFormat.format(displayAmount),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isMotorIncluded) ...[
                          Text(
                            '모터포함',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: isSimulated,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _simulatedMotorIds.add(est.id);
                                  } else {
                                    _simulatedMotorIds.remove(est.id);
                                  }
                                });
                              },
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              activeColor: scheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isSimulated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+40만 가산됨',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          est.modelName ?? QuoterTypeStyle.label(_selectedType),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: headerColor.withValues(alpha: 0.9),
                          ),
                        ),
                        if (est.description != null &&
                            est.description!.isNotEmpty)
                          Text(
                            est.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        Text(
                          '유사도: ${se.score}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

}

class _QuoterQuickActionItem {
  const _QuoterQuickActionItem({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Future<void> Function() onTap;
}
