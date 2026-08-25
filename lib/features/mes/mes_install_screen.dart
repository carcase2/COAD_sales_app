import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MesInstallScreen extends ConsumerStatefulWidget {
  const MesInstallScreen({super.key});

  @override
  ConsumerState<MesInstallScreen> createState() => _MesInstallScreenState();
}

class _MesInstallScreenState extends ConsumerState<MesInstallScreen> {
  List<dynamic> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = <dynamic>[];
    for (final st in ['SHIPPED', 'MFG_COMPLETE', 'INSTALLING', 'ORDERED']) {
      final data = await ref.read(mesRepositoryProvider).get('/api/orders?status=$st');
      all.addAll(data['orders'] as List? ?? []);
    }
    if (mounted) setState(() => _rows = all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시공완료 확인')),
      body: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final r = _rows[i] as Map;
          return ListTile(
            title: Text('${r['site_name'] ?? ''}'),
            subtitle: Text('${r['requested_install_date'] ?? ''} · ${r['status']}'),
            trailing: TextButton(
              onPressed: () async {
                await ref.read(mesRepositoryProvider).post(
                  '/api/orders/${r['id']}/installation/complete',
                  {
                    'startTime': '09:00',
                    'endTime': '17:00',
                    'photos': [
                      {
                        'originalName': 'offline.jpg',
                        'storageKey': 'pending:offline.jpg',
                        'clientUploadId': DateTime.now().millisecondsSinceEpoch.toString(),
                      }
                    ],
                  },
                );
                await _load();
              },
              child: const Text('시공완료'),
            ),
          );
        },
      ),
    );
  }
}
