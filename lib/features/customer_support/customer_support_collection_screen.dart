import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_completion_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

enum _CollectKind { paid, free, done, overdue }

class _CollectEvent {
  const _CollectEvent({
    required this.ymd,
    required this.title,
    required this.kind,
    required this.amountLabel,
  });

  final String ymd;
  final String title;
  final _CollectKind kind;
  final String amountLabel;
}

class CustomerSupportCollectionScreen extends StatefulWidget {
  const CustomerSupportCollectionScreen({super.key});

  @override
  State<CustomerSupportCollectionScreen> createState() =>
      _CustomerSupportCollectionScreenState();
}

class _CustomerSupportCollectionScreenState
    extends State<CustomerSupportCollectionScreen> {
  late final DateTime _today;
  late DateTime _focused;
  DateTime? _selected;
  String _filter = 'all';

  late final List<_CollectEvent> _events;

  @override
  void initState() {
    super.initState();
    _today = DateTime.parse(todayYmdSeoul());
    _focused = DateTime(_today.year, _today.month, _today.day);
    _selected = _focused;
    final today = todayYmdSeoul();
    _events = [
      _CollectEvent(
        ymd: addDaysToYmd(today, -2),
        title: '강남 코아드빌딩',
        kind: _CollectKind.overdue,
        amountLabel: '유상 220,000',
      ),
      _CollectEvent(
        ymd: today,
        title: '수성 한빛아파트',
        kind: _CollectKind.paid,
        amountLabel: '유상 85,000',
      ),
      _CollectEvent(
        ymd: addDaysToYmd(today, 3),
        title: '송도 물류센터',
        kind: _CollectKind.free,
        amountLabel: '무상',
      ),
      _CollectEvent(
        ymd: addDaysToYmd(today, 7),
        title: '강남 코아드빌딩 잔금',
        kind: _CollectKind.done,
        amountLabel: '입금완료 220,000',
      ),
    ];
  }

  List<_CollectEvent> _eventsOn(DateTime day) {
    final ymd = ymdSeoulFromDateTime(day);
    return _events
        .where((e) {
          if (e.ymd != ymd) return false;
          return switch (_filter) {
            'paid' =>
              e.kind == _CollectKind.paid || e.kind == _CollectKind.overdue,
            'free' => e.kind == _CollectKind.free,
            'done' => e.kind == _CollectKind.done,
            _ => true,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected ?? _focused;
    final dayEvents = _eventsOn(selected);
    final overdue = _events.where((e) => e.kind == _CollectKind.overdue).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('수금관리'),
        actions: const [SupportExcelButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const SupportComingSoonBanner(
            message: '입금예정일은 달력에 자동 등록될 자리입니다. 지난 건 알람·통계는 다음 작업입니다.',
          ),
          if (overdue > 0) ...[
            const SizedBox(height: 10),
            Material(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  Icons.notification_important_outlined,
                  color: scheme.onErrorContainer,
                ),
                title: Text(
                  '예정일이 지난 수금 $overdue건',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  '알람으로 챙기는 흐름입니다.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                onTap: () => showSupportSkeletonSnack(context, '수금 알람'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('전체'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              ChoiceChip(
                label: const Text('유상'),
                selected: _filter == 'paid',
                onSelected: (_) => setState(() => _filter = 'paid'),
              ),
              ChoiceChip(
                label: const Text('무상'),
                selected: _filter == 'free',
                onSelected: (_) => setState(() => _filter = 'free'),
              ),
              ChoiceChip(
                label: const Text('입금완료'),
                selected: _filter == 'done',
                onSelected: (_) => setState(() => _filter = 'done'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TableCalendar<void>(
            firstDay: DateTime(_today.year - 1, 1, 1),
            lastDay: DateTime(_today.year + 1, 12, 31),
            focusedDay: _focused,
            selectedDayPredicate: (d) =>
                _selected != null && isSameDay(d, _selected),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selected = selectedDay;
                _focused = focusedDay;
              });
            },
            onPageChanged: (focused) => _focused = focused,
            locale: 'ko_KR',
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTokens.customerSupportAccent(
                  scheme,
                ).withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppTokens.customerSupportAccent(scheme),
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, _) {
                final ev = _eventsOn(day);
                if (ev.isEmpty) return null;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final e in ev.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _kindColor(e.kind, scheme),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              _Legend(color: scheme.error, label: '미수금'),
              _Legend(color: scheme.tertiary, label: '입금예정'),
              _Legend(color: AppTokens.success(scheme), label: '입금완료'),
              _Legend(color: scheme.outline, label: '무상'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '선택일 일정',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (dayEvents.isEmpty)
            Text(
              '이 날 등록된 수금이 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (final e in dayEvents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: _kindColor(e.kind, scheme),
                ),
                title: Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(e.amountLabel),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomerSupportCompletionScreen(),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Text(
            'C. 통계',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(
                child: _StatBox(label: '수금예정', value: '305,000'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatBox(label: '입금완료', value: '220,000'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatBox(label: '미수', value: '220,000'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _kindColor(_CollectKind kind, ColorScheme scheme) => switch (kind) {
    _CollectKind.overdue => scheme.error,
    _CollectKind.paid => scheme.tertiary,
    _CollectKind.done => AppTokens.success(scheme),
    _CollectKind.free => scheme.outline,
  };
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
