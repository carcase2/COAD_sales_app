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
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = DateTime(_focused.year, _focused.month, 1);
    final to = DateTime(_focused.year, _focused.month + 1, 0);
    try {
      final data = await ref.read(mesRepositoryProvider).get(
        '/api/calendar?from=${from.toIso8601String().substring(0, 10)}&to=${to.toIso8601String().substring(0, 10)}',
      );
      if (mounted) setState(() => _events = data['events'] as List? ?? []);
    } catch (_) {}
  }

  List<dynamic> _forDay(DateTime day) {
    final key = day.toIso8601String().substring(0, 10);
    return _events.where((e) => '${e['start']}'.startsWith(key)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MES 달력')),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2035),
            focusedDay: _focused,
            eventLoader: _forDay,
            onPageChanged: (d) {
              _focused = d;
              _load();
            },
          ),
          Expanded(
            child: ListView(
              children: _forDay(_focused).map((e) => ListTile(
                title: Text('${e['title']}'),
                subtitle: Text('${e['extendedProps']?['layer'] ?? ''}'),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
