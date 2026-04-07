import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/data/ai_extractor_service.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesCallCreateScreen extends ConsumerStatefulWidget {
  const SalesCallCreateScreen({super.key});

  @override
  ConsumerState<SalesCallCreateScreen> createState() => _SalesCallCreateScreenState();
}

class _SalesCallCreateScreenState extends ConsumerState<SalesCallCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rawMemoCtrl = TextEditingController();   // AI 원문 메모
  final _inquiryCtrl = TextEditingController();   // AI 가 채워주는 요약
  final _stageCtrl = TextEditingController(text: '1차');

  String? _productId;
  String? _regionId;
  String? _methodId;
  int? _statusId = 1;
  bool _submitting = false;
  bool _aiLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _rawMemoCtrl.dispose();
    _inquiryCtrl.dispose();
    _stageCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAiExtract() async {
    final memo = _rawMemoCtrl.text.trim();
    if (memo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원문 메모를 먼저 입력해 주세요.')),
      );
      return;
    }
    final key = geminiApiKey;
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('.env 에 GEMINI_API_KEY 가 없습니다.')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final result = await AiExtractorService(apiKey: key).extract(memo);
      setState(() {
        _statusId = result.statusId;
        _stageCtrl.text = result.callStage;
        _inquiryCtrl.text = result.inquiryContent;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ AI 분석 완료! 내용을 확인 후 수정하세요.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 분석 실패: ${koreanErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _submit(MasterDataBundle master) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final user = ref.read(authControllerProvider);
      final body = <String, dynamic>{
        'customer_name': _nameCtrl.text.trim(),
        'customer_phone': _phoneCtrl.text.trim(),
        'inquiry_content': _inquiryCtrl.text.trim(),
        if (_productId != null) 'product_category_id': _productId,
        if (_regionId != null) 'region_id': _regionId,
        if (_methodId != null) 'inquiry_method_id': _methodId,
        'status_id': _statusId ?? 1,
        if (user != null) 'created_by': user.id,
        if (_stageCtrl.text.trim().isNotEmpty) 'call_stage': _stageCtrl.text.trim(),
      };

      NamedMasterRow? regionRow;
      if (_regionId != null) {
        for (final r in master.regions) {
          if (r.id == _regionId) { regionRow = r; break; }
        }
      }
      if (regionRow != null) {
        final e = regionRow.extra;
        if (e['sido'] != null) body['region_sido'] = e['sido'];
        if (e['region'] != null) body['region_name'] = e['region'];
        if (e['manager'] != null) body['region_manager'] = e['manager'];
        if (e['branch_type'] != null) body['region_branch_type'] = e['branch_type'];
      }

      final created = await ref.read(salesCallsRepositoryProvider).createCall(body);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SalesCallDetailScreen(id: created.id, initial: created),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(koreanErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('신규 고객전화')),
      body: masterAsync.when(
        data: (master) => _buildForm(master),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(koreanErrorMessage(e)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(masterDataProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(MasterDataBundle master) {
    final scheme = Theme.of(context).colorScheme;

    Widget sectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12, left: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: scheme.onSurface)),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── AI 메모 섹션 ───
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer.withOpacity(0.6), scheme.secondaryContainer.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('AI 메모 자동 분석', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary, fontSize: 15)),
                    const Spacer(),
                    Text('Gemini 1.5 Flash', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rawMemoCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: '예) 3차 발신. 단가 알아보고 연락달라 하심. 다음주 월요일 재연락 예정.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: scheme.surface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _aiLoading ? null : _runAiExtract,
                    icon: _aiLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_aiLoading ? 'AI 분석 중...' : '✨ AI로 자동 분석'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          sectionTitle('고객 정보', Icons.person),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: '고객명 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '고객명을 입력하세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: '전화번호 *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android)),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '전화번호를 입력하세요.';
                      if (!isValidKoreanPhone(v)) return '전화번호 형식을 확인하세요.';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),

          sectionTitle('상담 내용 (AI 자동 입력)', Icons.support_agent),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _inquiryCtrl,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: '요약된 문의 내용',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _inquiryCtrl.text.isNotEmpty
                          ? Icon(Icons.check_circle, color: Colors.green.shade600)
                          : null,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '문의 내용을 입력하세요.' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _statusId ?? 1,
                          decoration: const InputDecoration(labelText: '진행 상태', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('미통화 (1)')),
                            DropdownMenuItem(value: 2, child: Text('진행중 (2)')),
                            DropdownMenuItem(value: 3, child: Text('수주 (3)')),
                            DropdownMenuItem(value: 4, child: Text('단순문의 (4)')),
                            DropdownMenuItem(value: 5, child: Text('설계문의 (5)')),
                          ],
                          onChanged: (v) => setState(() => _statusId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stageCtrl,
                          decoration: const InputDecoration(labelText: '콜 차수', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          sectionTitle('부가 정보', Icons.tune),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: _productId,
                    decoration: const InputDecoration(labelText: '분류 (제품군)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
                      ...master.productCategories.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                    ],
                    onChanged: (v) => setState(() => _productId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _regionId,
                    decoration: const InputDecoration(labelText: '지역', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
                      ...master.regions.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                    ],
                    onChanged: (v) => setState(() => _regionId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: _methodId,
                    decoration: const InputDecoration(labelText: '문의 유입 경로', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
                      ...master.inquiryMethods.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name))),
                    ],
                    onChanged: (v) => setState(() => _methodId = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(master),
              icon: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_submitting ? '등록 중...' : '통화 등록', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
