import 'package:coad_customer_calls/core/utils/mes_permissions.dart';
import 'package:coad_customer_calls/features/mes/mes_calendar_screen.dart';
import 'package:coad_customer_calls/features/mes/mes_order_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MesHomeScreen extends ConsumerStatefulWidget {
  const MesHomeScreen({super.key});

  @override
  ConsumerState<MesHomeScreen> createState() => _MesHomeScreenState();
}

class _MesHomeScreenState extends ConsumerState<MesHomeScreen> {
  late final PageController _page;
  int _index = 0;
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(mesRepositoryProvider).get('/api/home/summary');
      if (mounted) setState(() => _summary = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final pages = <Widget>[];
    final titles = <String>[];
    if (canMes(user, 'mes.orders.view')) {
      titles.add('영업');
      pages.add(_listCard('오늘 등록', (_summary['sales']?['items'] as List?) ?? []));
    }
    if (canMes(user, 'mes.manufacturing.view')) {
      titles.add('제조');
      pages.add(_queue());
    }
    if (canMes(user, 'mes.installation.view')) {
      titles.add('시공');
      pages.add(_listCard('오늘 시공', (_summary['installation']?['today'] as List?) ?? []));
    }
    if (canMes(user, 'mes.payments.view')) {
      titles.add('수금');
      pages.add(_pay());
    }
    if (pages.isEmpty) {
      return const Scaffold(body: Center(child: Text('MES 권한이 없습니다.')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index.clamp(0, titles.length - 1)]),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () {
            Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MesCalendarScreen()));
          }),
        ],
      ),
      floatingActionButton: canMes(user, 'mes.orders.create')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(builder: (_) => const MesOrderScreen()),
                );
                if (saved == true) await _load();
              },
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('영업 등록'),
            )
          : null,
      body: Column(
        children: [
          if (titles.length > 1)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(titles.length, (i) => Container(
                  width: i == _index ? 18 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _index ? Theme.of(context).colorScheme.primary : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              children: pages,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listCard(String title, List items) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (items.isEmpty) const Text('없음'),
        ...items.map((e) => ListTile(title: Text('${e['site_name'] ?? ''}'))),
      ],
    );
  }

  Widget _queue() {
    final q = (_summary['manufacturing']?['queue'] as List?) ?? [];
    return ListView(
      children: q.map((e) {
        final id = e['id'] as String?;
        return ListTile(
          title: Text('${e['site_name'] ?? ''}'),
          trailing: TextButton(
            onPressed: id == null ? null : () async {
              await ref.read(mesRepositoryProvider).post('/api/orders/$id/manufacturing/complete');
              await _load();
            },
            child: const Text('제조완료'),
          ),
        );
      }).toList(),
    );
  }

  Widget _pay() {
    final due = (_summary['collection']?['dueToday'] as List?) ?? [];
    final ov = (_summary['collection']?['overdue'] as List?) ?? [];
    return ListView(
      children: [
        const ListTile(title: Text('오늘 입금예정')),
        ...due.map((e) => ListTile(
          title: Text('${e['mes_orders']?['site_name'] ?? ''}'),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(mesRepositoryProvider).post('/api/payments/${e['id']}/collect');
              await _load();
            },
            child: const Text('입금'),
          ),
        )),
        const ListTile(title: Text('연체', style: TextStyle(color: Colors.red))),
        ...ov.map((e) => ListTile(
          title: Text('${e['mes_orders']?['site_name'] ?? ''}'),
          trailing: TextButton(
            onPressed: () async {
              await ref.read(mesRepositoryProvider).post('/api/payments/${e['id']}/collect');
              await _load();
            },
            child: const Text('입금'),
          ),
        )),
      ],
    );
  }
}
