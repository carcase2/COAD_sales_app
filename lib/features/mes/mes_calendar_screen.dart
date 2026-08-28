import 'package:coad_customer_calls/core/utils/mes_permissions.dart';
import 'package:coad_customer_calls/features/mes/mes_order_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

class MesCalendarScreen extends ConsumerStatefulWidget {
  const MesCalendarScreen({super.key});

  @override
  ConsumerState<MesCalendarScreen> createState() => _MesCalendarScreenState();
}

class _MesCalendarScreenState extends ConsumerState<MesCalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  List<dynamic> _events = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final from = DateTime(_focused.year, _focused.month, 1);
    final to = DateTime(_focused.year, _focused.month + 1, 0);
    try {
      final data = await ref.read(mesRepositoryProvider).get(
        '/api/calendar?from=${_ymd(from)}&to=${_ymd(to)}',
      );
      if (mounted) setState(() => _events = data['events'] as List? ?? []);
    } catch (_) {}
  }

  List<dynamic> _forDay(DateTime day) {
    final key = _ymd(day);
    return _events.where((e) => '${e['start']}'.startsWith(key)).toList();
  }

  Future<void> _openSales() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => MesOrderScreen(initialInstallDate: _ymd(_selected)),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _reschedule(Map event) async {
    final ext = event['extendedProps'];
    final props = ext is Map ? Map<String, dynamic>.from(ext) : <String, dynamic>{};
    final orderId = '${props['orderId'] ?? ''}';
    final layer = '${props['layer'] ?? ''}';
    final from = '${event['start']}'.substring(0, 10);
    if (orderId.isEmpty || layer != 'install') return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(from) ?? _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: '시공예정일',
    );
    if (picked == null) return;
    final to = _ymd(picked);
    if (to == from) return;
    setState(() => _busy = true);
    final res = await ref.read(mesRepositoryProvider).patch(
      '/api/orders/$orderId/install-plan',
      {'fromDate': from, 'toDate': to},
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final status = res['_status'] as int? ?? 0;
    if (status >= 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${res['error'] ?? '시공일을 바꾸지 못했습니다.'}')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('시공일을 바꿨습니다.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final canCreate = canMes(user, 'mes.orders.create');
    final dayEvents = _forDay(_selected);
    return Scaffold(
      appBar: AppBar(title: const Text('MES 달력')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openSales,
              icon: const Icon(Icons.add),
              label: Text('${_selected.month}/${_selected.day} 영업 등록'),
            )
          : null,
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2035),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: _forDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selected = selected;
                _focused = focused;
              });
            },
            onPageChanged: (d) {
              _focused = d;
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selected.year}년 ${_selected.month}월 ${_selected.day}일 · 시공예정 ${dayEvents.where((e) => (e['extendedProps'] is Map) && e['extendedProps']['layer'] == 'install').length}건',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Text(
                      canCreate ? '이 날 일정이 없습니다. 아래 버튼으로 영업 등록하세요.' : '이 날 일정이 없습니다.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  )
                : ListView.separated(
                    itemCount: dayEvents.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = dayEvents[i] as Map;
                      final ext = e['extendedProps'];
                      final props = ext is Map ? Map<String, dynamic>.from(ext) : <String, dynamic>{};
                      final layer = '${props['layer'] ?? ''}';
                      final isInstall = layer == 'install';
                      return ListTile(
                        title: Text('${e['title']}'),
                        subtitle: Text(isInstall ? '시공예정 · 눌러서 날짜 변경' : layer),
                        trailing: isInstall ? const Icon(Icons.event_repeat) : null,
                        onTap: isInstall ? () => _reschedule(e) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
