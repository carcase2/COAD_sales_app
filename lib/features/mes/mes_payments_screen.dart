import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MesPaymentsScreen extends ConsumerStatefulWidget {
  const MesPaymentsScreen({super.key});

  @override
  ConsumerState<MesPaymentsScreen> createState() => _MesPaymentsScreenState();
}

class _MesPaymentsScreenState extends ConsumerState<MesPaymentsScreen> {
  List<dynamic> _rows = [];
  String _today = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(mesRepositoryProvider).get('/api/payments');
    if (mounted) {
      setState(() {
        _rows = data['payments'] as List? ?? [];
        _today = '${data['today'] ?? ''}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MES 수금')),
      body: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final r = _rows[i] as Map;
          final due = '${r['due_date'] ?? ''}';
          final overdue = due.compareTo(_today) < 0 &&
              (num.tryParse('${r['paid_amount'] ?? 0}') ?? 0) <
                  (num.tryParse('${r['amount'] ?? 0}') ?? 0);
          final site = r['mes_orders']?['site_name'] ?? '';
          return ListTile(
            tileColor: overdue ? Colors.red.shade50 : null,
            title: Text('$site'),
            subtitle: Text('$due · ${r['amount']}'),
            trailing: r['status'] == 'PAID'
                ? const Text('완료')
                : TextButton(
                    onPressed: () async {
                      await ref.read(mesRepositoryProvider).post('/api/payments/${r['id']}/collect');
                      await _load();
                    },
                    child: const Text('입금'),
                  ),
          );
        },
      ),
    );
  }
}
