// ignore_for_file: unused_element

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
import 'package:coad_customer_calls/features/quoter/shutter_estimate_notice.dart';
import 'package:coad_customer_calls/features/quoter/similar_estimates_notifier.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_out_of_table_warning.dart';
import 'package:coad_customer_calls/features/quoter/widgets/quoter_size_keypad.dart';
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

  /// 규격 키패드: true = 폭 편집, false = 높이 편집 (시스템 키보드 없음)
  bool _editingWidth = true;

  // 비용 직접 수정용 컨트롤러
  // 기본 비용 — COAD_home ShutterEstimatorWizard DEFAULT_COSTS 와 동일
  final _motorCostController = TextEditingController(text: '400,000');
  final _installCostController = TextEditingController(text: '800,000');
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

  int get _widthMm =>
      int.tryParse(_widthController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  int get _heightMm =>
      int.tryParse(_heightController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  TextEditingController get _activeSizeController =>
      _editingWidth ? _widthController : _heightController;

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
    _motorCostController.dispose();
    _installCostController.dispose();
    _equipCostController.dispose();
    _bendingCostController.dispose();
    _profitCostController.dispose();
    super.dispose();
  }

  void _invalidateCalculatedResult() {
    if (_result == null || _isCalculating) return;
    // 규격 변경 시 결과 무효화
    if (_currentStep == 2) {
      setState(() {
        _result = null;
        _similarLookupInput = null;
        _companyComparisons = const [];
      });
      return;
    }
    setState(() {
      _result = null;
      _similarLookupInput = null;
      _companyComparisons = const [];
    });
  }

  void _appendSizeDigit(String digit) {
    final c = _activeSizeController;
    final raw = c.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length >= 5) return;
    final next = '$raw$digit';
    // 선행 0 방지
    final cleaned = next.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    c.text = cleaned;
    setState(() {});
  }

  void _backspaceSize() {
    final c = _activeSizeController;
    final raw = c.text.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return;
    c.text = raw.substring(0, raw.length - 1);
    setState(() {});
  }

  void _clearSize() {
    _activeSizeController.clear();
    setState(() {});
  }

  void _setActiveSizeMm(int mm) {
    if (mm <= 0) return;
    _activeSizeController.text = '$mm';
    // 빠른 칩: 폭 입력 후 바로 높이로
    setState(() {
      if (_editingWidth) _editingWidth = false;
    });
  }

  void _onSizeKeypadPrimary() {
    if (_editingWidth) {
      if (_widthMm <= 0) return;
      setState(() => _editingWidth = false);
      return;
    }
    if (_canCalculate && !_isCalculating) {
      unawaited(_goToStep(4));
    }
  }

  void _resetToDefaults() {
    setState(() {
      // COAD_home DEFAULT_COSTS 와 동일
      _motorCostController.text = '400,000';
      _installCostController.text = '800,000';
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
      _editingWidth = true;
      _result = null;
      _similarLookupInput = null;
      _simulatedMotorIds.clear();
      _selectedCompanyId = null;
      _companyComparisons = const [];
      _resetToDefaults();
      _currentStep = 1;
    });
  }

  /// 규격 단계 진입 시 비어 있는 축부터 편집
  void _prepareSizeEditing() {
    FocusScope.of(context).unfocus();
    if (_widthMm <= 0) {
      _editingWidth = true;
    } else if (_heightMm <= 0) {
      _editingWidth = false;
    }
  }

  Future<void> _goToStep(int step) async {
    if (step == _currentStep) return;
    // 결과(4)는 폭·높이 있을 때만 진입 — 없으면 규격 단계로 안내
    if (step == 4 && !_canCalculate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('폭과 높이를 입력한 뒤 견적을 산출해 주세요.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      setState(() {
        _currentStep = 2;
        _prepareSizeEditing();
      });
      return;
    }
    setState(() {
      _currentStep = step;
      if (step == 2) _prepareSizeEditing();
    });
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
      // 1차: 현재 선택(또는 기본) 업체로 비교표 구성
      var comparisons = _buildCompanyComparisons(
        prices: prices,
        input: input,
        selectedCompanyId: companyContext.selectedCompanyId,
      );
      // 웹과 동일: 산출 직후 최저가 업체로 자동 적용
      final lowestId = _lowestCompanyId(comparisons);
      final preferredId = lowestId ?? companyContext.selectedCompanyId;
      final preferredContext = preferredId == companyContext.selectedCompanyId
          ? companyContext
          : _buildCompanyContext(
              prices: prices,
              selectedCompanyId: preferredId,
            );
      final preferredCompany = preferredContext.selectedCompany;
      final preferredUnitMap =
          preferredCompany == null || preferredCompany.id == _baseCompanyId
          ? null
          : ShutterCalculator.unitPriceMapFromCompany(
              preferredCompany.toJson(),
              preferredContext.fallbackUnitPriceMap,
            );
      final res = ShutterCalculator.calculate(
        input: input,
        gridPrices: prices['grid'] as List<Map<String, dynamic>>,
        unitPrices: prices['unit'] as List<Map<String, dynamic>>,
        unitPriceOverrideMap: preferredUnitMap,
      );
      comparisons = _buildCompanyComparisons(
        prices: prices,
        input: input,
        selectedCompanyId: preferredContext.selectedCompanyId,
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
        _selectedCompanyId = preferredContext.selectedCompanyId;
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

  /// COAD_home: 기준 단가(비와이메탈) + 등록 업체 목록.
  static const _baseCompanyId = '__base_unit_price__';
  static const _baseCompanyName = '비와이메탈';

  CompanyContext _buildCompanyContext({
    required Map<String, List<Map<String, dynamic>>> prices,
    required String? selectedCompanyId,
  }) {
    final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
      prices['unit'] as List<Map<String, dynamic>>,
    );
    final companies = _comparisonCompanies(
      rawRows: prices['company'] ?? const [],
      fallbackMap: fallbackMap,
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

  /// 웹과 동일: 비와이메탈(기준) + 회사 단가 테이블 업체.
  List<ShutterCompanyUnitPrice> _comparisonCompanies({
    required List<Map<String, dynamic>> rawRows,
    required Map<String, int> fallbackMap,
  }) {
    final registered = _parseCompanyRows(rawRows);
    final hasBaseName = registered.any(
      (c) => c.companyName.replaceAll(' ', '') == _baseCompanyName,
    );
    if (hasBaseName) return registered;

    final base = ShutterCompanyUnitPrice(
      id: _baseCompanyId,
      companyName: _baseCompanyName,
      unitPriceGeneral: fallbackMap['이중압출'] ?? 81000,
      unitPriceInsulated: fallbackMap['이중압출단열'] ?? 144000,
      isDefault: true,
      sortOrder: -1,
    );
    return [base, ...registered];
  }

  List<CompanyComparisonRow> _buildCompanyComparisons({
    required Map<String, List<Map<String, dynamic>>> prices,
    required ShutterEstimateInput input,
    required String? selectedCompanyId,
  }) {
    if (!ShutterCalculator.isSecurityType(_selectedType)) return const [];
    final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
      prices['unit'] as List<Map<String, dynamic>>,
    );
    final companies = _comparisonCompanies(
      rawRows: prices['company'] ?? const [],
      fallbackMap: fallbackMap,
    );
    if (companies.isEmpty) return const [];

    final rows = companies.map((company) {
      // 기준(비와이메탈)은 unit 테이블 단가, 그 외는 회사 단가 오버라이드
      final Map<String, int>? unitMap = company.id == _baseCompanyId
          ? null
          : ShutterCalculator.unitPriceMapFromCompany(
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

  /// 산출 직 최저가 업체 자동 선택 (COAD_home generateEstimate).
  String? _lowestCompanyId(List<CompanyComparisonRow> rows) {
    if (rows.isEmpty) return null;
    CompanyComparisonRow? minRow;
    for (final row in rows) {
      if (row.totalAmount <= 0) continue;
      if (minRow == null || row.totalAmount < minRow.totalAmount) {
        minRow = row;
      }
    }
    return minRow?.company.id;
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
    final unitMap =
        selectedCompany == null || selectedCompany.id == _baseCompanyId
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
    final accent = quoterStepAccent(_currentStep);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelTint = accent.withValues(alpha: isDark ? 0.12 : 0.085);
    final panelBorder = accent.withValues(alpha: isDark ? 0.52 : 0.34);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;
    // 종류(1)·규격(2)·결과(4): 크롬 최소화 → 본문 공간 최대
    final denseChrome =
        _currentStep == 1 || _currentStep == 2 || _currentStep == 4;
    final hidePriceBar = denseChrome || keyboardOpen;
    // 종류: 탭하면 바로 규격. 규격/결과: 화면 안 네비만. 비용은 단계 칩(3).
    final hideWizardActions =
        _currentStep == 1 ||
        _currentStep == 2 ||
        _currentStep == 4 ||
        keyboardOpen;
    final hideWizardHeader =
        _currentStep == 4 || (_currentStep == 2 && keyboardOpen);
    final outerPad = denseChrome
        ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
        : const EdgeInsets.fromLTRB(16, 12, 16, 12);

    return Padding(
      padding: outerPad,
      child: Column(
        children: [
          if (!hidePriceBar) ...[
            _buildPriceSyncBar(scheme),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(panelTint, scheme.surface),
                  border: Border.all(color: panelBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hideWizardHeader)
                      Container(
                        height: denseChrome ? 3 : 5,
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
                        padding: EdgeInsets.fromLTRB(
                          denseChrome ? 6 : 10,
                          denseChrome ? 4 : 10,
                          denseChrome ? 6 : 10,
                          denseChrome ? 2 : 8,
                        ),
                        child: Column(
                          children: [
                            if (!hideWizardHeader) ...[
                              _buildWizardHeader(scheme),
                              SizedBox(height: denseChrome ? 4 : 8),
                            ],
                            if (!hideWizardActions) ...[
                              _buildWizardActions(scheme),
                              const SizedBox(height: 8),
                            ],
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 120),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
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
        // 스크롤 없이 6종 한 화면 (Grid가 남은 높이에 맞춤)
        return KeyedSubtree(
          key: const ValueKey('step1'),
          child: _buildTypeSelector(scheme),
        );
      case 2:
        // 시스템 키보드 없이 앱 내 숫자 패드 — 높이에 맞춰 압축
        return QuoterSizeKeypad(
          key: const ValueKey('step2'),
          widthMm: _widthMm,
          heightMm: _heightMm,
          editingWidth: _editingWidth,
          onSelectWidth: () => setState(() => _editingWidth = true),
          onSelectHeight: () => setState(() => _editingWidth = false),
          onDigit: _appendSizeDigit,
          onBackspace: _backspaceSize,
          onClear: _clearSize,
          onSetValue: _setActiveSizeMm,
          onBack: () => unawaited(_goToStep(1)),
          onPrimary: _onSizeKeypadPrimary,
          canCalculate: _canCalculate,
          isCalculating: _isCalculating,
          outOfTable: _isOutOfTableSizeRange,
          outOfTableBanner: _isOutOfTableSizeRange
              ? const QuoterOutOfTableWarning()
              : null,
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
        // 결과: 넓은 본문 + 하단 네비(산출 전에도 처음부터/규격 항상 표시)
        return Column(
          key: const ValueKey('step4'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_result == null)
              _buildCalculateButton(scheme)
            else
              _buildStep4ResultTopBar(scheme),
            const SizedBox(height: 6),
            Expanded(
              child: _result == null
                  ? _buildStep4Placeholder(scheme)
                  : _buildResultCompactCard(scheme),
            ),
            _buildStep4BottomNav(scheme),
          ],
        );
    }
  }

  Widget _buildStep4Placeholder(ColorScheme scheme) {
    final a = quoterStepAccent(4);
    final canCalc = _canCalculate;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canCalc ? Icons.calculate_rounded : Icons.straighten_rounded,
              size: 42,
              color: a,
            ),
            const SizedBox(height: 10),
            Text(
              canCalc ? '최종 견적 산출' : '규격 입력이 필요합니다',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: a,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canCalc
                  ? '아래 또는 상단 버튼으로 견적을 계산하세요.'
                  : '폭·높이를 입력한 뒤 견적을 산출할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (!canCalc)
              FilledButton.tonalIcon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  unawaited(_goToStep(2));
                },
                icon: const Icon(Icons.straighten_rounded),
                label: const Text(
                  '규격 입력하러 가기',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
              )
            else
              FilledButton.icon(
                onPressed: _isCalculating ? null : _calculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text(
                  '지금 산출',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 48),
                  backgroundColor: a,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardActions(ColorScheme scheme) {
    // 이전/다음 — 낮은 높이로 본문 공간 확보
    const btnH = 36.0;
    final btnStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(btnH)),
      maximumSize: const WidgetStatePropertyAll(Size.fromHeight(btnH)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );

    // 2단계(규격): 견적 산출은 화면 안 버튼만 사용 — 하단 중복 제거
    if (_currentStep == 2) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  unawaited(_goToStep(1));
                },
                style: btnStyle,
                child: const Text('이전'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  unawaited(_goToStep(3));
                },
                style: btnStyle,
                child: const Text('비용 설정'),
              ),
            ),
            if (_hasAnyInput) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: '다시 견적내기',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _newEstimate();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
              ),
            ],
          ],
        ),
      );
    }

    final canNext = _currentStep < 4;
    final canPrev = _currentStep > 1;
    final nextEnabled = _currentStep != 4 && canNext;
    final navAccent = quoterStepAccent(_currentStep);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canPrev
                  ? () {
                      HapticFeedback.lightImpact();
                      unawaited(_goToStep(_currentStep - 1));
                    }
                  : null,
              style: btnStyle.copyWith(
                foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: const Text('이전'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: !nextEnabled
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      final nextStep = _currentStep < 4
                          ? _currentStep + 1
                          : null;
                      if (nextStep != null) await _goToStep(nextStep);
                    },
              style: btnStyle.copyWith(
                backgroundColor: WidgetStatePropertyAll(navAccent),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
              ),
              child: const Text('다음'),
            ),
          ),
          if (_hasAnyInput) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: '다시 견적내기',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.mediumImpact();
                _newEstimate();
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 20),
            ),
          ],
        ],
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
  // 비용 설정 — 한 줄 행 · 작은 글씨로 한눈에
  // ─────────────────────────────────────────────────
  Widget _buildCostSettings(ColorScheme scheme) {
    final a = quoterStepAccent(3);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: a.withValues(alpha: 0.4), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: a),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '비용 설정',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: a,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetToDefaults,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  child: const Text(
                    '기본값',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          // 요약 한 줄 — 접혀 있어도 금액 파악
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _buildCostSummaryStrip(scheme),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          _buildCostFields(scheme),
        ],
      ),
    );
  }

  /// 모터·시공 등 현재 값을 한 줄 요약
  Widget _buildCostSummaryStrip(ColorScheme scheme) {
    String short(TextEditingController c) {
      final v = int.tryParse(c.text.replaceAll(',', '')) ?? 0;
      if (v >= 10000) {
        final man = v / 10000;
        if (man == man.roundToDouble()) {
          return '${man.round()}만';
        }
        return '${man.toStringAsFixed(man < 10 ? 1 : 0)}만';
      }
      return NumberFormat('#,###').format(v);
    }

    final items = [
      ('모터', short(_motorCostController)),
      ('시공', short(_installCostController)),
      ('장비', short(_equipCostController)),
      ('절곡', short(_bendingCostController)),
      ('이익', short(_profitCostController)),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${e.$1} ${e.$2}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCostFields(ColorScheme scheme) {
    final fields = <({String label, IconData icon, TextEditingController c})>[
      (
        label: '모터가격',
        icon: Icons.settings_remote_rounded,
        c: _motorCostController,
      ),
      (
        label: '시공비',
        icon: Icons.construction_rounded,
        c: _installCostController,
      ),
      (
        label: '장비대',
        icon: Icons.precision_manufacturing_rounded,
        c: _equipCostController,
      ),
      (
        label: '절곡비용',
        icon: Icons.architecture_rounded,
        c: _bendingCostController,
      ),
      (
        label: '당사이익',
        icon: Icons.trending_up_rounded,
        c: _profitCostController,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            _buildSettingsField(
              label: fields[i].label,
              icon: fields[i].icon,
              controller: fields[i].c,
              scheme: scheme,
            ),
          ],
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
      setState(() {}); // 요약 칩 갱신
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 6),
          // 모터가격·시공비 등 — 글자 수만큼 공간 확보 (잘림 방지)
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 6),
          _buildAdjustButton(
            icon: Icons.remove_rounded,
            onPressed: () => adjustPrice(-50000),
            scheme: scheme,
          ),
          const SizedBox(width: 4),
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
              onChanged: (_) {
                _invalidateCalculatedResult();
                setState(() {});
              },
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.15,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                suffixText: '원',
                suffixStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: quoterStepAccent(3),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _buildAdjustButton(
            icon: Icons.add_rounded,
            onPressed: () => adjustPrice(50000),
            scheme: scheme,
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Icon(icon, size: 15, color: scheme.primary),
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

  /// 결과 단계 하단 — 처음부터 / 규격 (항상 표시)
  Widget _buildStep4BottomNav(ColorScheme scheme) {
    final sizeLabel = _result != null ? '규격 수정' : '규격 입력';
    return Material(
      color: scheme.surface,
      elevation: 3,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _newEstimate();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '처음부터',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  unawaited(_goToStep(2));
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.straighten_rounded, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sizeLabel,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4ResultTopBar(ColorScheme scheme) {
    final typeColor = QuoterTypeStyle.color(_selectedType);
    final typeLabel = QuoterTypeStyle.label(_selectedType);
    final w = _result?.input.widthMm.round() ?? 0;
    final h = _result?.input.heightMm.round() ?? 0;
    final sizeLabel = (w > 0 && h > 0)
        ? '${NumberFormat('#,###').format(w)} × ${NumberFormat('#,###').format(h)} mm'
        : '';
    return Material(
      color: typeColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        child: Row(
          children: [
            Icon(
              _isFireDoorType
                  ? Icons.local_fire_department_rounded
                  : Icons.check_circle_rounded,
              size: 18,
              color: typeColor,
            ),
            const SizedBox(width: 8),
            // 종류 + 규격을 두 줄로 — 한 줄 말줄임으로 잘리지 않게
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    typeLabel,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      color: typeColor,
                    ),
                  ),
                  if (sizeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sizeLabel,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: '다시 산출',
              onPressed: _isCalculating ? null : _calculate,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              color: typeColor,
            ),
          ],
        ),
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
                if (ShutterCalculator.isSecurityType(_selectedType)) ...[
                  const SizedBox(height: 10),
                  Text(
                    kShutterSlatUnitPriceNotice,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                ],
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

  bool get _isFireDoorType =>
      _selectedType == ShutterType.fireSteel ||
      _selectedType == ShutterType.fireScreen;

  Widget _buildResultCompactCard(ColorScheme scheme) {
    // 방화: 현재 총액 대신 격자 안내 + 유사 견적 중심
    if (_isFireDoorType) {
      return _buildFireDoorResultBody(scheme);
    }

    final result = _result!;
    final typeColor = QuoterTypeStyle.color(_selectedType);
    final selectedName = () {
      for (final row in _companyComparisons) {
        if (row.company.id == _selectedCompanyId) {
          return row.company.companyName;
        }
      }
      return null;
    }();
    final hasCompanies = _companyComparisons.isNotEmpty;

    // 방범: 제조사별 가격이 본문 중심 · 총액/상세는 보조
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 상단 요약 바 — 적용 총액 + 상세 진입 (짧게)
        Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: typeColor.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedName != null
                                ? '적용 총액 · $selectedName'
                                : '적용 총액',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _krwFormat.format(result.totalAmount),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: typeColor,
                                letterSpacing: -0.8,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ResultQuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: '견적 내역',
                      onTap: () => _showBreakdownSheet(scheme),
                      scheme: scheme,
                    ),
                    const SizedBox(width: 6),
                    _ResultQuickAction(
                      icon: Icons.memory_rounded,
                      label: '기술 사양',
                      onTap: () => _showSpecsSheet(scheme),
                      scheme: scheme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 본문: 제조사 비교 + 하단 안내(전체 표시, 필요 시 스크롤)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 8),
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasCompanies)
                  _buildCompanyComparisonCard(scheme, featured: true)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '제조사 비교 데이터가 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  kShutterSlatUnitPriceNotice,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 철제방화/스크린방화 결과 — 총액 강조 없이 격자 안내 + 유사 견적.
  Widget _buildFireDoorResultBody(ColorScheme scheme) {
    final result = _result!;
    final typeColor = QuoterTypeStyle.color(_selectedType);
    final typeLabel = QuoterTypeStyle.label(_selectedType);
    final w = result.input.widthMm.round();
    final h = result.input.heightMm.round();
    String? installNote;
    for (final e in result.breakdown) {
      if (e.name.contains('시공')) {
        installNote = e.note;
        break;
      }
    }
    final hasGridPrice = result.totalAmount > 0;

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: typeColor.withValues(alpha: 0.07),
            border: Border.all(color: typeColor.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    QuoterTypeStyle.icon(_selectedType),
                    size: 18,
                    color: typeColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: typeColor,
                      ),
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(w)}×'
                    '${NumberFormat('#,###').format(h)} mm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasGridPrice) ...[
                Text(
                  '격자 예상 시공비',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_krwFormat.format(result.totalAmount)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    letterSpacing: -0.5,
                  ),
                ),
                if (installNote != null && installNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    installNote,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이 사이즈는 단가 격자에 없어 총액 산출이 없습니다. '
                        '아래 비슷한 사이즈 이전 견적을 참고하거나 담당자에게 문의해 주세요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '방화 모델은 스라트·모터 합산 견적이 아닌 격자 시공비·유사 사례 중심입니다.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _buildSimilarEstimatesSection(scheme),
      ],
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
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: false,
      backgroundColor: scheme.surface,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.72;
        return SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '기술 사양',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
              Expanded(
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
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
                              _buildSpecItem(
                                '권장 모터',
                                _result!.motorModel,
                                scheme,
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              _buildSpecItem(
                                '소비전력',
                                _result!.powerSpec,
                                scheme,
                              ),
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
                              _buildSpecItem(
                                '롤파이프',
                                ShutterCalculator.getRollPipeType(
                                  _result!.input.widthMm,
                                ),
                                scheme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '브라켓·박스 규칙은 COAD_home 견적기와 동일합니다. '
                      '폭 7,500mm 이상이면 8인치 롤파이프 및 모터 1단계 상향이 적용됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBreakdownSheet(ColorScheme scheme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // 리스트 스크롤과 시트 드래그가 겹치면 뒤 화면이 비침 → 핸들/바깥 탭으로만 닫기
      enableDrag: false,
      backgroundColor: scheme.surface,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
        return SizedBox(
          height: maxH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '견적 내역',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
              Expanded(
                child: ListView(
                  // 바운스/오버스크롤이 뒤 화면을 끌어올리지 않도록
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    if (_companyComparisons.isNotEmpty) ...[
                      _buildCompanyDeltaSummaryCard(scheme),
                      const SizedBox(height: 12),
                    ],
                    _buildGroupedBreakdown(scheme),
                  ],
                ),
              ),
            ],
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

  Widget _buildCompanyComparisonCard(
    ColorScheme scheme, {
    bool featured = false,
  }) {
    if (_companyComparisons.isEmpty) {
      return const SizedBox.shrink();
    }
    // 총액 낮은 순 — 비교만 간결하게
    final sorted = [..._companyComparisons]
      ..sort((a, b) {
        final byPrice = a.totalAmount.compareTo(b.totalAmount);
        if (byPrice != 0) return byPrice;
        return a.company.companyName.compareTo(b.company.companyName);
      });
    final minRow = sorted.first;
    final minId = minRow.company.id;
    final isMinAlreadySelected = _selectedCompanyId == minId;
    final accent = QuoterTypeStyle.color(_selectedType);

    // 현재 적용 총액 vs 최저가 차액 → 제목 "제조사 비교" 오른쪽에만 표기
    CompanyComparisonRow? selectedRow;
    for (final row in _companyComparisons) {
      if (row.company.id == _selectedCompanyId) {
        selectedRow = row;
        break;
      }
    }
    final vsMin = selectedRow == null
        ? 0
        : selectedRow.totalAmount - minRow.totalAmount;
    final String? headerDelta;
    final Color headerDeltaColor;
    if (selectedRow == null || vsMin == 0) {
      headerDelta = isMinAlreadySelected ? '(최저)' : null;
      headerDeltaColor = Colors.green.shade800;
    } else if (vsMin > 0) {
      headerDelta = '(+${NumberFormat('#,###').format(vsMin)})';
      headerDeltaColor = Colors.red.shade700;
    } else {
      headerDelta = '(-${NumberFormat('#,###').format(vsMin.abs())})';
      headerDeltaColor = Colors.blue.shade700;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: featured
            ? scheme.surface
            : scheme.primaryContainer.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: featured
              ? accent.withValues(alpha: 0.28)
              : scheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '제조사 비교',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (headerDelta != null)
                        TextSpan(
                          text: ' $headerDelta',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: headerDeltaColor,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isMinAlreadySelected) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    unawaited(_onSelectCompany(minId));
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: accent,
                  ),
                  child: const Text(
                    '최저가 적용',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < sorted.length; i++)
            _buildCompanyComparisonRow(
              scheme: scheme,
              row: sorted[i],
              isLowest: sorted[i].company.id == minId,
              isLast: i == sorted.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildCompanyComparisonRow({
    required ColorScheme scheme,
    required CompanyComparisonRow row,
    required bool isLowest,
    bool isLast = false,
  }) {
    final isSelected = row.company.id == _selectedCompanyId;

    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.28)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          unawaited(_onSelectCompany(row.company.id));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: scheme.primary.withValues(alpha: 0.45))
                : (!isLast
                      ? Border(
                          bottom: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.28,
                            ),
                          ),
                        )
                      : null),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: isSelected
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.company.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (isLowest) ...[
                      const SizedBox(width: 4),
                      Text(
                        '최저',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Text(
                        '적용',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _krwFormat.format(row.totalAmount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
            ],
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
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
        padding: EdgeInsets.only(top: 16, bottom: 8),
        child: SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
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
        mainAxisSize: MainAxisSize.min,
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

/// 결과 상단 — 견적 내역 / 기술 사양 빠른 진입.
class _ResultQuickAction extends StatelessWidget {
  const _ResultQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
