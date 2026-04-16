import 'dart:async';
import 'dart:convert';

import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_create_screen.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/features/quoter/similar_estimates_notifier.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final shutterPriceRefreshKeyProvider = StateProvider<int>((ref) => 0);
const Duration _shutterPriceCacheTtl = Duration(hours: 24);

final shutterPricesFutureProvider = FutureProvider((ref) async {
  final repo = ref.read(shutterRepositoryProvider);
  final prefs = ref.read(appDependenciesProvider).prefs;
  final refreshKey = ref.watch(shutterPriceRefreshKeyProvider);
  final forceNetwork = refreshKey > 0;

  Future<Map<String, List<Map<String, dynamic>>>> fetchAndCache() async {
    final grid = await repo.fetchGridPrices();
    final unit = await repo.fetchUnitPrices();
    await prefs.setString(StorageKeys.shutterPriceGridCache, jsonEncode(grid));
    await prefs.setString(StorageKeys.shutterPriceUnitCache, jsonEncode(unit));
    await prefs.setString(StorageKeys.shutterPriceCachedAt, DateTime.now().toIso8601String());
    return {'grid': grid, 'unit': unit};
  }

  if (!forceNetwork) {
    final cachedGrid = prefs.getString(StorageKeys.shutterPriceGridCache);
    final cachedUnit = prefs.getString(StorageKeys.shutterPriceUnitCache);
    final cachedAtRaw = prefs.getString(StorageKeys.shutterPriceCachedAt);
    final cachedAt = cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw);
    final cacheIsFresh = cachedAt != null && DateTime.now().difference(cachedAt) < _shutterPriceCacheTtl;

    if (cachedGrid != null && cachedUnit != null && cacheIsFresh) {
      final grid = List<Map<String, dynamic>>.from(
        (jsonDecode(cachedGrid) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final unit = List<Map<String, dynamic>>.from(
        (jsonDecode(cachedUnit) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      return {'grid': grid, 'unit': unit};
    }
  }

  return fetchAndCache();
});

class QuoterScreen extends ConsumerStatefulWidget {
  const QuoterScreen({super.key});

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
  final NumberFormat _krwFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

  // -- State --
  ShutterType _selectedType = ShutterType.doubleExtrusion;
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // 비용 직접 수정용 컨트롤러
  final _motorCostController = TextEditingController(text: '400,000');
  final _installCostController = TextEditingController(text: '600,000');
  final _equipCostController = TextEditingController(text: '200,000');
  final _bendingCostController = TextEditingController(text: '500,000');
  final _profitCostController = TextEditingController(text: '800,000');

  ShutterEstimateResult? _result;
  ShutterEstimateInput? _similarLookupInput;
  final Set<String> _simulatedMotorIds = {};

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
    setState(() {
      _result = null;
      _similarLookupInput = null;
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
      _resetToDefaults();
      _currentStep = 1;
    });
  }

  void _onDimensionChanged(String _) {
    _invalidateCalculatedResult();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _goToStep(int step) async {
    if (step == _currentStep) return;
    setState(() {
      _currentStep = step;
      if (step == 3) _isCostSettingsExpanded = true;
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
        const SnackBar(content: Text('폭과 높이를 올바르게 입력해주세요.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCalculating = true);
    try {
      final prices = await ref.read(shutterPricesFutureProvider.future);

      final input = ShutterEstimateInput(
        type: _selectedType,
        widthMm: w,
        heightMm: h,
        includeInstallation: true,
        includeMotor: true,
        includeProfit: true,
        overrideMotorCost: int.tryParse(_motorCostController.text.replaceAll(',', '')),
        overrideInstallCost: int.tryParse(_installCostController.text.replaceAll(',', '')),
        overrideEquipCost: int.tryParse(_equipCostController.text.replaceAll(',', '')),
        overrideBendingCost: int.tryParse(_bendingCostController.text.replaceAll(',', '')),
        overrideProfitCost: int.tryParse(_profitCostController.text.replaceAll(',', '')),
      );

      final res = ShutterCalculator.calculate(
        input: input,
        gridPrices: prices['grid'] as List<Map<String, dynamic>>,
        unitPrices: prices['unit'] as List<Map<String, dynamic>>,
      );

      setState(() {
        _result = res;
        _similarLookupInput = ShutterEstimateInput(type: _selectedType, widthMm: w, heightMm: h);
        _currentStep = 4;
      });

      if (!mounted) return;

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
          ref.read(shutterRepositoryProvider).logEstimate({
            'user_id': userId,
            'user_name': userName,
            'width_mm': input.widthMm.toInt(),
            'height_mm': input.heightMm.toInt(),
            // 웹과 동일한 모델 문자열 사용
            'model_type': _getTypeLabel(_selectedType),
            // JSON number로 전송되도록 숫자 타입 유지
            'total_price': res.totalAmount,
            'created_at': DateTime.now().toIso8601String(),
          }).catchError((e) => debugPrint('Logging failed: $e')),
        );
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('계산 중 오류가 발생했습니다: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
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
          return _buildWithQuickActions(scheme, _buildContent(scheme));
        },
        loading: () => _buildWithQuickActions(
          scheme,
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: scheme.primary),
                const SizedBox(height: 16),
                Text('단가 데이터 로딩 중...', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        error: (e, stack) => _buildWithQuickActions(
          scheme,
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text('데이터 로딩 실패', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.error)),
                const SizedBox(height: 8),
                TextButton(onPressed: () => ref.invalidate(shutterPricesFutureProvider), child: const Text('다시 시도')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithQuickActions(ColorScheme scheme, Widget content) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final actionsBottom = 72.0 + safeBottom;
    final quickActions = <_QuoterQuickActionItem>[
      _QuoterQuickActionItem(
        label: '홈',
        color: Colors.blueGrey.shade700,
        icon: Icons.home_rounded,
        onTap: () async => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      _QuoterQuickActionItem(
        label: '접수',
        color: scheme.tertiary,
        icon: Icons.add_ic_call_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SalesCallCreateScreen()),
          );
        },
      ),
      _QuoterQuickActionItem(
        label: '미통화',
        color: Colors.orange.shade700,
        icon: Icons.pending_actions_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallListScreen(
                mode: ListQueryMode.incomplete,
                date: todayYmdSeoul(),
              ),
            ),
          );
        },
      ),
      _QuoterQuickActionItem(
        label: '금일팔로우',
        color: Colors.deepPurple.shade600,
        icon: Icons.event_note_rounded,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallListScreen(
                mode: ListQueryMode.incompleteByDate,
                date: todayYmdSeoul(),
                initialAssignee: '전체',
              ),
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
            MaterialPageRoute<bool>(
              builder: (_) => const IssuanceRequestCreateScreen(
                initialDomain: IssuanceDomain.taxInvoice,
              ),
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
                  constraints: const BoxConstraints(maxHeight: 240),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(item.icon, size: 18, color: item.color),
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
                                        Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
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
                onPressed: () => setState(() => _quickActionsOpen = !_quickActionsOpen),
                child: Icon(_quickActionsOpen ? Icons.close_rounded : Icons.menu_open_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    const bottomPad = 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad),
      child: Column(
        children: [
          _buildPriceSyncBar(scheme),
          const SizedBox(height: 8),
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
    );
  }

  String _formatSyncTime(DateTime value) {
    return DateFormat('MM/dd HH:mm').format(value);
  }

  Future<void> _refreshPricesManually() async {
    ref.read(shutterPriceRefreshKeyProvider.notifier).state++;
    ref.invalidate(shutterPricesFutureProvider);
    try {
      await ref.read(shutterPricesFutureProvider.future);
      if (!mounted) return;
      setState(() => _lastPriceSyncAt = DateTime.now());
      if (mounted) setState(() => _priceUpdateAvailable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단가를 최신값으로 갱신했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단가 새로고침에 실패했습니다.'), backgroundColor: Colors.red),
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
      setState(() => _priceUpdateAvailable = remoteGridJson != cachedGrid || remoteUnitJson != cachedUnit);
    } catch (_) {
      // 네트워크 실패 시에는 조용히 무시 (캐시 사용 지속)
    }
  }

  Widget _buildPriceSyncBar(ColorScheme scheme) {
    final syncText = _lastPriceSyncAt == null ? '단가 갱신 정보 없음' : '단가 갱신: ${_formatSyncTime(_lastPriceSyncAt!)}';
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
    Widget stepChip(int step, String label) {
      final active = _currentStep == step;
      final done = step < _currentStep || (step == 4 && _result != null);
      return Expanded(
        child: InkWell(
          onTap: () => _goToStep(step),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              color: active
                  ? scheme.primaryContainer
                  : done
                      ? scheme.tertiaryContainer.withValues(alpha: 0.75)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$step단계',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        stepChip(1, '종류'),
        const SizedBox(width: 6),
        stepChip(2, '규격'),
        const SizedBox(width: 6),
        stepChip(3, '비용'),
        const SizedBox(width: 6),
        stepChip(4, '결과'),
      ],
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
        return Container(
          key: const ValueKey('step4'),
          child: Column(
            children: [
              _buildCalculateButton(scheme),
              if (_selectedType == ShutterType.fireSteel || _selectedType == ShutterType.fireScreen)
                _buildSimilarEstimatesSection(scheme),
              const SizedBox(height: 10),
              Expanded(
                child: _result == null
                    ? _buildStep4Placeholder(scheme)
                    : SingleChildScrollView(child: _buildResultCard(scheme)),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildStep4Placeholder(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_rounded, size: 42, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              '최종 견적 산출',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
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

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
      children: [
        if (_hasAnyInput)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _newEstimate,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('다시 견적내기'),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canPrev ? () => _goToStep(_currentStep - 1) : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                        if (_currentStep < 4) await _goToStep(_currentStep + 1);
                      },
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('다음'),
              ),
            ),
          ],
        ),
      ],
    ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 셔터 종류 선택
  // ─────────────────────────────────────────────────
  Widget _buildTypeSelector(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.view_module_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text('1단계 · 셔터 종류 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            ],
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.9,
          children: ShutterType.values.map((t) {
            final isSelected = _selectedType == t;
            final color = _getTypeColor(t);
            final icon = _getTypeIcon(t);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = t);
                _invalidateCalculatedResult();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.25),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: isSelected ? Colors.white : color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _getTypeLabel(t),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : color.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // 규격 입력
  // ─────────────────────────────────────────────────
  Widget _buildSizeInput(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
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
                      Icon(Icons.straighten_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2단계 · 규격 입력 (mm)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (!compact && _result != null)
                        TextButton.icon(
                          onPressed: _newEstimate,
                          icon: const Icon(Icons.restart_alt_rounded, size: 16),
                          label: const Text('초기화', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.error,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                    ],
                  ),
                  if (compact && _result != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _newEstimate,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('초기화', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSizeField(label: '폭 (W)', controller: _widthController, scheme: scheme, hint: '3000'),
          const SizedBox(height: 12),
          _buildSizeField(label: '높이 (H)', controller: _heightController, scheme: scheme, hint: '3000'),
        ],
      ),
    );
  }

  Widget _buildSizeField({
    required String label,
    required TextEditingController controller,
    required ColorScheme scheme,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
                onChanged: _onDimensionChanged,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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

  // ─────────────────────────────────────────────────
  // 비용 설정 (접이식)
  // ─────────────────────────────────────────────────
  Widget _buildCostSettings(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // 헤더 (탭해서 펼치기)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isCostSettingsExpanded = !_isCostSettingsExpanded);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tune_rounded, size: 18, color: scheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('3단계 · 비용 설정', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                        Text(
                          _isCostSettingsExpanded ? '탭하여 접기' : '탭하여 상세 비용 조정',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: _isCostSettingsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          // 펼쳐지는 내용
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildCostFields(scheme),
            crossFadeState: _isCostSettingsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
                _buildSettingsField(label: '모터가격', icon: Icons.settings_remote_rounded, controller: _motorCostController, scheme: scheme),
                const Divider(height: 1),
                _buildSettingsField(label: '시공비', icon: Icons.construction_rounded, controller: _installCostController, scheme: scheme),
                const Divider(height: 1),
                _buildSettingsField(label: '장비대', icon: Icons.precision_manufacturing_rounded, controller: _equipCostController, scheme: scheme),
                const Divider(height: 1),
                _buildSettingsField(label: '절곡비용', icon: Icons.architecture_rounded, controller: _bendingCostController, scheme: scheme),
                const Divider(height: 1),
                _buildSettingsField(label: '당사이익', icon: Icons.trending_up_rounded, controller: _profitCostController, scheme: scheme),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              Icon(icon, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
                  onChanged: (_) => _invalidateCalculatedResult(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    suffixText: ' 원',
                    suffixStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 16, color: scheme.primary),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 견적 산출 버튼
  // ─────────────────────────────────────────────────
  Widget _buildCalculateButton(ColorScheme scheme) {
    final typeColor = _getTypeColor(_selectedType);
    final enabled = _canCalculate && !_isCalculating;
    return GestureDetector(
      onTap: enabled ? _calculate : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: !enabled
              ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
              : LinearGradient(
                  colors: [typeColor, scheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: !enabled
              ? []
              : [
                  BoxShadow(color: typeColor.withValues(alpha: 0.40), blurRadius: 16, offset: const Offset(0, 6)),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isCalculating)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            else
              const Icon(Icons.calculate_rounded, color: Colors.white, size: 24),
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

  // ─────────────────────────────────────────────────
  // 결과 카드
  // ─────────────────────────────────────────────────
  Widget _buildResultCard(ColorScheme scheme) {
    final typeColor = _getTypeColor(_selectedType);

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
          BoxShadow(color: typeColor.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: typeColor.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 총액 헤더 ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                colors: [typeColor.withValues(alpha: 0.08), typeColor.withValues(alpha: 0.02)],
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getTypeLabel(_selectedType),
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
                            textAlign: compact ? TextAlign.right : TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '최종 견적 금액',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaPill(
                      label: '셔터 종류',
                      value: _getTypeLabel(_selectedType),
                      scheme: scheme,
                    ),
                    _buildMetaPill(
                      label: '규격',
                      value: '${_widthController.text} × ${_heightController.text} mm',
                      scheme: scheme,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _krwFormat.format(_result!.totalAmount),
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: typeColor, letterSpacing: -1.5),
                  ),
                ),
                const SizedBox(height: 16),
                // 요약 칩
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildSummaryChip(label: '스라트', amount: slatTotal, color: Colors.blue.shade600, scheme: scheme, note: _result!.slatPriceNote),
                    _buildSummaryChip(label: '시공비', amount: installTotal, color: Colors.orange.shade700, scheme: scheme),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOpenSheetTile(
                  icon: Icons.memory_rounded,
                  title: '기술 사양 보기',
                  subtitle: '권장 모터 · 소비전력 · 셔터박스 · 브라켓 종류',
                  onTap: () => _showSpecsSheet(scheme),
                  scheme: scheme,
                ),
                const SizedBox(height: 10),
                _buildOpenSheetTile(
                  icon: Icons.receipt_long_rounded,
                  title: '견적 상세 내역 보기 (${_result!.breakdown.length}건)',
                  subtitle: '자재/모터 · 시공/부대 · 기타',
                  onTap: () => _showBreakdownSheet(scheme),
                  scheme: scheme,
                ),
                const SizedBox(height: 16),
                // 합계 강조
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text('합계', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: typeColor)),
                      const Spacer(),
                      Text(
                        _krwFormat.format(_result!.totalAmount),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: typeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          final subtotal = items.fold<int>(0, (int sum, ShutterBreakdownItem e) => sum + e.amount);
          final isLastGroup = idx == keys.length - 1;

          return Container(
            decoration: BoxDecoration(
              border: isLastGroup
                  ? null
                  : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.22))),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: idx == 0
                        ? const BorderRadius.vertical(top: Radius.circular(16))
                        : BorderRadius.zero,
                  ),
                  child: Row(
                    children: [
                        if (key == '자재/모터') ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer.withValues(alpha: 0.7),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: isLastLine
                          ? null
                          : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.16))),
                      borderRadius: isLastGroup && isLastLine
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
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

  Widget _buildMaterialTypeBadge(ShutterBreakdownItem item, ColorScheme scheme) {
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
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
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
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
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
            Icon(Icons.open_in_new_rounded, size: 18, color: scheme.onSurfaceVariant),
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
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        _buildSpecItem('추정 무게', '${_result!.weightKg.toStringAsFixed(1)} kg', scheme),
                        _buildSpecItem('권장 모터', _result!.motorModel, scheme),
                      ]),
                      const Divider(height: 20),
                      Row(children: [
                        _buildSpecItem('소비전력', _result!.powerSpec, scheme),
                        _buildSpecItem('셔터박스', _result!.boxSize, scheme),
                      ]),
                      const Divider(height: 20),
                      Row(
                        children: [
                          _buildSpecItem('브라켓 종류', _result!.bracketType, scheme),
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
              child: _buildGroupedBreakdown(scheme),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyEstimateToClipboard() async {
    final r = _result;
    if (r == null) return;
    final width = _widthController.text.trim().isEmpty ? '-' : _widthController.text.trim();
    final height = _heightController.text.trim().isEmpty ? '-' : _heightController.text.trim();
    final sb = StringBuffer();
    sb.writeln('[셔터 견적서]');
    sb.writeln('셔터 종류: ${_getTypeLabel(_selectedType)}');
    sb.writeln('규격(mm): $width x $height');
    sb.writeln('브라켓 종류: ${r.bracketType}');
    sb.writeln('총액: ${_krwFormat.format(r.totalAmount)}');
    sb.writeln('산출시각: ${r.calculatedAt}');
    sb.writeln('');
    sb.writeln('[상세]');
    for (final item in r.breakdown) {
      sb.writeln('- ${_compactItemName(item.name)}: ${_krwFormat.format(item.amount)}');
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('견적 내용이 복사되었습니다.')),
    );
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
        Icon(icon, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurface)),
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
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
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
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${NumberFormat('#,###').format(amount)}원',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, ColorScheme scheme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
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
    if (_selectedType != ShutterType.fireSteel && _selectedType != ShutterType.fireScreen) {
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
                    child: Icon(Icons.history_rounded, size: 16, color: scheme.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('비슷한 사이즈 이전 견적',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, size: 18, color: scheme.onSurfaceVariant),
                    onPressed: () => ref.invalidate(similarEstimatesProvider(tempInput)),
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
              if (withMotor.isNotEmpty) _buildSimilarGroupCard('모터 포함', withMotor, scheme, isMotorIncluded: true),
              if (withMotor.isNotEmpty && withoutMotor.isNotEmpty) const SizedBox(height: 10),
              if (withoutMotor.isNotEmpty) _buildSimilarGroupCard('모터 미포함', withoutMotor, scheme, isMotorIncluded: false),
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
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.9)),
        ),
      ),
    );
  }

  Widget _buildSimilarGroupCard(String title, List<ScoredEstimate> items, ColorScheme scheme, {required bool isMotorIncluded}) {
    final headerColor = isMotorIncluded ? Colors.teal.shade700 : Colors.orange.shade700;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: headerColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: headerColor.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Icon(isMotorIncluded ? Icons.settings_remote_rounded : Icons.handyman_rounded, size: 14, color: headerColor),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: headerColor)),
              ],
            ),
          ),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final se = entry.value;
            final est = se.estimate;
            final isSimulated = _simulatedMotorIds.contains(est.id);
            final displayAmount = isSimulated ? est.amount + 400000 : est.amount;
            final isLast = idx == items.length - 1;

            return InkWell(
              onTap: () {},
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(18)) : BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${est.width.round()}×${est.height.round()}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _krwFormat.format(displayAmount),
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: scheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isMotorIncluded) ...[
                          Text('모터포함', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
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
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('+40만 가산됨', style: TextStyle(fontSize: 11, color: scheme.primary, fontWeight: FontWeight.bold)),
                          ),
                        Text(
                          est.modelName ?? _getTypeLabel(_selectedType),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: headerColor.withValues(alpha: 0.9)),
                        ),
                        if (est.description != null && est.description!.isNotEmpty)
                          Text(est.description!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.9))),
                        Text(
                          '유사도: ${se.score}',
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
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

  String _getTypeLabel(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion: return '이중압출';
      case ShutterType.doubleExtrusionInsulated: return '이중압출단열';
      case ShutterType.windproof: return '내풍압';
      case ShutterType.windproofInsulated: return '내풍압단열';
      case ShutterType.fireSteel: return '철제방화';
      case ShutterType.fireScreen: return '스크린방화';
    }
  }

  IconData _getTypeIcon(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion: return Icons.layers_rounded;
      case ShutterType.doubleExtrusionInsulated: return Icons.layers_clear_rounded;
      case ShutterType.windproof: return Icons.air_rounded;
      case ShutterType.windproofInsulated: return Icons.shield_rounded;
      case ShutterType.fireSteel: return Icons.local_fire_department_rounded;
      case ShutterType.fireScreen: return Icons.fire_extinguisher_rounded;
    }
  }

  Color _getTypeColor(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion: return const Color(0xFF1565C0);
      case ShutterType.doubleExtrusionInsulated: return const Color(0xFF0277BD);
      case ShutterType.windproof: return const Color(0xFF283593);
      case ShutterType.windproofInsulated: return const Color(0xFF4527A0);
      case ShutterType.fireSteel: return const Color(0xFF37474F);
      case ShutterType.fireScreen: return const Color(0xFFE65100);
    }
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

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final intValue = int.tryParse(newValue.text.replaceAll(',', ''));
    if (intValue == null) return oldValue;
    final formatted = NumberFormat('#,###').format(intValue);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
