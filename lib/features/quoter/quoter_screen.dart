import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/features/quoter/similar_estimates_notifier.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:coad_customer_calls/models/similar_shutter_model.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final shutterPricesFutureProvider = FutureProvider((ref) async {
  final repo = ref.read(shutterRepositoryProvider);
  final grid = await repo.fetchGridPrices();
  final unit = await repo.fetchUnitPrices();
  return {'grid': grid, 'unit': unit};
});

class QuoterScreen extends ConsumerStatefulWidget {
  const QuoterScreen({super.key});

  @override
  ConsumerState<QuoterScreen> createState() => _QuoterScreenState();
}

class _QuoterScreenState extends ConsumerState<QuoterScreen> {
  late ScrollController _scrollController;
  bool _isBottomBarVisible = true;
  
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

  bool _includeProfit = true;
  ShutterEstimateResult? _result;
  final Set<String> _simulatedMotorIds = {}; // 가상 모터 적용 ID 추적

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // 탭 진입 시 바가 보이도록 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bottomBarVisibilityProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _widthController.dispose();
    _heightController.dispose();
    _motorCostController.dispose();
    _installCostController.dispose();
    _equipCostController.dispose();
    _bendingCostController.dispose();
    _profitCostController.dispose();
    _scrollController.dispose();
    super.dispose();
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
      _widthController.clear();
      _heightController.clear();
      _result = null;
      _simulatedMotorIds.clear();
      _resetToDefaults();
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onScroll() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      if (_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = false);
        ref.read(bottomBarVisibilityProvider.notifier).state = false;
      }
    } else if (direction == ScrollDirection.forward) {
      if (!_isBottomBarVisible) {
        setState(() => _isBottomBarVisible = true);
        ref.read(bottomBarVisibilityProvider.notifier).state = true;
      }
    }
  }

  Future<void> _calculate() async {
    try {
      final prices = await ref.read(shutterPricesFutureProvider.future);
      
      final input = ShutterEstimateInput(
        type: _selectedType,
        widthMm: double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0,
        heightMm: double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0,
        includeInstallation: true,
        includeMotor: true,
        includeProfit: _includeProfit,
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

      setState(() => _result = res);
      
      if (!mounted) return;

      // 결과가 나오면 하단으로 부드럽게 스크롤
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('견적이 산출되었습니다.'), duration: Duration(seconds: 1)),
      );

      // 로깅 (비동기, 결과에 지장 주지 않음)
      final currentUser = ref.read(authControllerProvider);
      final dbInfo = ShutterCalculator.getDbInfo(_selectedType);
      ref.read(shutterRepositoryProvider).logEstimate({
        'user_id': currentUser?.id,
        'user_name': currentUser?.name,
        'width_mm': input.widthMm.toInt(),
        'height_mm': input.heightMm.toInt(),
        'model_type': dbInfo['model_type'] ?? dbInfo['category'],
        'total_price': res.totalAmount,
        'created_at': DateTime.now().toIso8601String(),
      }).catchError((e) => debugPrint('Logging failed: $e'));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('계산 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pricesAsync = ref.watch(shutterPricesFutureProvider);

    return pricesAsync.when(
      data: (_) => _buildContent(scheme),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('데이터 로딩 실패: $e')),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24).copyWith(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputCard(scheme),
          _buildSimilarEstimatesSection(scheme), // 비슷한 사이즈 리스트 추가
          const SizedBox(height: 24),
          if (_result != null) _buildResultCard(scheme),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme scheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_note_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('견적 조건 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface)),
                ),
                TextButton.icon(
                  onPressed: _newEstimate,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('새로 시작', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 모델 선택
            Text('셔터 종류', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.primary)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
              children: ShutterType.values.map((t) {
                final isSelected = _selectedType == t;
                final color = _getTypeColor(t);
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                      ] : null,
                    ),
                    child: Text(
                      _getTypeLabel(t),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : color.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 규격 입력
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: '폭 (W) mm',
                    controller: _widthController,
                    scheme: scheme,
                    hint: '3000',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: '높이 (H) mm',
                    controller: _heightController,
                    scheme: scheme,
                    hint: '3000',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('비용 설정', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.primary)),
                TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('기본값으로 초기화', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSettingsField(
                    label: '모터가격',
                    controller: _motorCostController,
                    scheme: scheme,
                  ),
                  const Divider(height: 24),
                  _buildSettingsField(
                    label: '장비대',
                    controller: _equipCostController,
                    scheme: scheme,
                  ),
                  const Divider(height: 24),
                  _buildSettingsField(
                    label: '절곡비용',
                    controller: _bendingCostController,
                    scheme: scheme,
                  ),
                  const Divider(height: 24),
                  _buildSettingsField(
                    label: '당사이익',
                    controller: _profitCostController,
                    scheme: scheme,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 계산 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('견적 산출하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsField({
    required String label,
    required TextEditingController controller,
    required ColorScheme scheme,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: Text(
                label, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              )
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45), // 최대 45% 너비 사용
              child: SizedBox(
                width: 140, // 적정 너비 시도
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, _ThousandsFormatter()],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: ' 원',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildResultCard(ColorScheme scheme) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
    
    // 요약 합계 계산
    int slatTotal = 0;
    int installTotal = 0;
    for (final item in _result!.breakdown) {
      if (item.name.contains('스라트')) {
        slatTotal += item.amount;
      } else if (item.name == '시공 예상 비용') {
        installTotal = item.amount; // 시공비 칩은 순수 시공비만 표시
      }
    }

    return Card(
      elevation: 4,
      shadowColor: scheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.white, scheme.primaryContainer.withValues(alpha: 0.05)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text('최종 견적 금액', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.primary)),
                Text(_result!.calculatedAt, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant.withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                currencyFormat.format(_result!.totalAmount),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: scheme.primary, letterSpacing: -1),
              ),
            ),
            
            const SizedBox(height: 16),
            // 요약 칩
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                 _buildSummaryChip(
                  label: '스라트',
                  amount: slatTotal,
                  color: Colors.blue,
                  scheme: scheme,
                  note: _result!.slatPriceNote,
                ),
                _buildSummaryChip(
                  label: '시공비',
                  amount: installTotal,
                  color: Colors.orange,
                  scheme: scheme,
                ),
              ],
            ),

            const SizedBox(height: 24),
            // 기술 사양 그리드
            Text('기술 사양', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildSpecItem('추정 무게', '${_result!.weightKg.toStringAsFixed(1)} kg', scheme),
                      _buildSpecItem('권장 모터', _result!.motorModel, scheme),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _buildSpecItem('소비전력', _result!.powerSpec, scheme),
                      _buildSpecItem('셔터박스', _result!.boxSize, scheme),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 40),
            Text('견적 상세 내역', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSurface)),
            const SizedBox(height: 12),
            ..._result!.breakdown.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.name, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  Text(currencyFormat.format(item.amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required int amount,
    required Color color,
    required ColorScheme scheme,
    String? note, // 추가: 계산 근거
  }) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$label ${currencyFormat.format(amount)}원',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                note,
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
              ),
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
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required ColorScheme scheme,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsFormatter(),
          ],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
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
  Widget _buildSimilarEstimatesSection(ColorScheme scheme) {
    if (_selectedType != ShutterType.fireSteel && _selectedType != ShutterType.fireScreen) {
      return const SizedBox.shrink();
    }

    final width = double.tryParse(_widthController.text.replaceAll(',', '')) ?? 0;
    final height = double.tryParse(_heightController.text.replaceAll(',', '')) ?? 0;

    if (width <= 0 || height <= 0) return const SizedBox.shrink();

    final tempInput = ShutterEstimateInput(
      type: _selectedType,
      widthMm: width,
      heightMm: height,
    );

    final similarAsync = ref.watch(similarEstimatesProvider(tempInput));

    return similarAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();

        final withMotor = list.where((e) => e.estimate.hasMotor).toList();
        final withoutMotor = list.where((e) => !e.estimate.hasMotor).toList();

        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '비슷한 사이즈 리스트 (최근 견적 데이터)', 
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: scheme.secondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () => ref.invalidate(similarEstimatesProvider(tempInput)),
                    tooltip: '데이터 새로고침',
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
                _buildSimilarGroupCard('모터 포함 항목', withMotor, scheme, isMotorIncluded: true),
              if (withMotor.isNotEmpty && withoutMotor.isNotEmpty) const SizedBox(height: 16),
              if (withoutMotor.isNotEmpty)
                _buildSimilarGroupCard('모터 미포함 항목', withoutMotor, scheme, isMotorIncluded: false),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, __) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text('유사 데이터 로딩 실패: $e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }

  Widget _buildSimilarGroupCard(String title, List<ScoredEstimate> items, ColorScheme scheme, {required bool isMotorIncluded}) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant)),
          ),
          ...items.map((se) {
            final est = se.estimate;
            final isSimulated = _simulatedMotorIds.contains(est.id);
            final displayAmount = isSimulated ? est.amount + 400000 : est.amount;

            return InkWell(
              onTap: () {}, // 클릭 효과 유지
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단: 규격, 가격 및 체크박스
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${est.width.round()}x${est.height.round()}', 
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSecondaryContainer)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currencyFormat.format(displayAmount), 
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isMotorIncluded) ...[
                          Text('모터포함', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
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
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 하단: 모델명, 업체설명, 점수 (Wrap 사용하여 넘침 방지)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isSimulated) 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text('+40만 가산됨', style: TextStyle(fontSize: 9, color: scheme.primary, fontWeight: FontWeight.bold)),
                          ),
                        Text(
                          est.modelName ?? _getTypeLabel(_selectedType), 
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: scheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        if (est.description != null && est.description!.isNotEmpty) 
                          Text(
                            est.description!, 
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                          ),
                        Text(
                          '유사도: ${se.score}', 
                          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
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

  Color _getTypeColor(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion: return Colors.blue.shade700;
      case ShutterType.doubleExtrusionInsulated: return Colors.lightBlue.shade600;
      case ShutterType.windproof: return Colors.indigo.shade600;
      case ShutterType.windproofInsulated: return Colors.deepPurple.shade600;
      case ShutterType.fireSteel: return Colors.blueGrey.shade700;
      case ShutterType.fireScreen: return Colors.orange.shade800;
    }
  }
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

