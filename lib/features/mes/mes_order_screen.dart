import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MesOrderScreen extends ConsumerStatefulWidget {
  const MesOrderScreen({super.key});

  @override
  ConsumerState<MesOrderScreen> createState() => _MesOrderScreenState();
}

class _MesOrderScreenState extends ConsumerState<MesOrderScreen> {
  final _customer = TextEditingController();
  final _site = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _qty = TextEditingController(text: '1');
  String? _productId;
  List<dynamic> _products = [];
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(mesRepositoryProvider).get('/api/products');
    if (mounted) {
      setState(() {
        _products = data['products'] as List? ?? [];
        if (_products.isNotEmpty) _productId = _products.first['id'] as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('MES 영업 등록')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _customer, decoration: const InputDecoration(labelText: '발주처')),
          TextField(controller: _site, decoration: const InputDecoration(labelText: '현장명')),
          DropdownButtonFormField<String>(
            value: _productId,
            items: _products
                .map((p) => DropdownMenuItem(value: p['id'] as String, child: Text('${p['code']}')))
                .toList(),
            onChanged: (v) => setState(() => _productId = v),
            decoration: const InputDecoration(labelText: '모델'),
          ),
          TextField(controller: _qty, decoration: const InputDecoration(labelText: '수량'), keyboardType: TextInputType.number),
          TextField(controller: _width, decoration: const InputDecoration(labelText: '너비 mm'), keyboardType: TextInputType.number),
          TextField(controller: _height, decoration: const InputDecoration(labelText: '높이 mm'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final body = {
                'customer': {'name': _customer.text},
                'site': {'name': _site.text},
                'branchCode': '1000',
                'salesUserId': user?.id ?? '',
                'items': [
                  {
                    'productId': _productId,
                    'qty': int.tryParse(_qty.text) ?? 1,
                    'widthMm': int.tryParse(_width.text) ?? 0,
                    'heightMm': int.tryParse(_height.text) ?? 0,
                    'motor': 'L',
                  }
                ],
                'confirmShortage': true,
              };
              final res = await ref.read(mesRepositoryProvider).post('/api/orders', body);
              setState(() => _msg = res['error']?.toString() ?? '등록 ${res['order']?['inquiry_no'] ?? '완료'}');
            },
            child: const Text('등록'),
          ),
          if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg)),
        ],
      ),
    );
  }
}
