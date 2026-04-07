import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
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
  final _inquiryCtrl = TextEditingController();

  String? _productId;
  String? _regionId;
  String? _methodId;
  int? _statusId;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inquiryCtrl.dispose();
    super.dispose();
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
      };

      NamedMasterRow? regionRow;
      if (_regionId != null) {
        for (final r in master.regions) {
          if (r.id == _regionId) {
            regionRow = r;
            break;
          }
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
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '고객명 *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '고객명을 입력하세요.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '전화번호 *',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '전화번호를 입력하세요.';
              if (!isValidKoreanPhone(v)) return '전화번호 형식을 확인하세요.';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _inquiryCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '문의 내용 *',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '문의 내용을 입력하세요.' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: _productId,
            decoration: const InputDecoration(
              labelText: '제품군',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
              ...master.productCategories.map(
                (e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name)),
              ),
            ],
            onChanged: (v) => setState(() => _productId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _regionId,
            decoration: const InputDecoration(
              labelText: '지역',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
              ...master.regions.map(
                (e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name)),
              ),
            ],
            onChanged: (v) => setState(() => _regionId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _methodId,
            decoration: const InputDecoration(
              labelText: '문의 방법',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('선택 안 함')),
              ...master.inquiryMethods.map(
                (e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.name)),
              ),
            ],
            onChanged: (v) => setState(() => _methodId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _statusId ?? 1,
            decoration: const InputDecoration(
              labelText: '상태',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('미결정 (1)')),
              DropdownMenuItem(value: 2, child: Text('미수주 (2)')),
              DropdownMenuItem(value: 3, child: Text('수주 (3)')),
              DropdownMenuItem(value: 4, child: Text('단순문의 (4)')),
              DropdownMenuItem(value: 5, child: Text('설계문의 (5)')),
            ],
            onChanged: (v) => setState(() => _statusId = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(master),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('등록'),
          ),
        ],
      ),
    );
  }
}
