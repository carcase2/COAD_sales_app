import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListQueryMode { today, incomplete, recent, completedToday, incompleteByDate }

class SalesCallListScreen extends ConsumerStatefulWidget {
  const SalesCallListScreen({super.key, required this.mode, this.date});

  final ListQueryMode mode;
  final String? date;

  @override
  ConsumerState<SalesCallListScreen> createState() => _SalesCallListScreenState();
}

class _SalesCallListScreenState extends ConsumerState<SalesCallListScreen> {
  late Future<List<SalesCall>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SalesCall>> _load() {
    final repo = ref.read(salesCallsRepositoryProvider);
    switch (widget.mode) {
      case ListQueryMode.today:
        return repo.fetchCalls(
          date: todayYmdSeoul(),
          limit: 100,
          includeCallHistory: true,
        );
      case ListQueryMode.incomplete:
        return repo.fetchCalls(
          date: todayYmdSeoul(),
          incompleteOnly: true,
          excludeSimpleInquiries: true,
          limit: 100,
          includeCallHistory: true,
        );
      case ListQueryMode.recent:
        return repo.fetchCalls(
          limit: 50,
          offset: 0,
          includeCallHistory: false,
        );
      case ListQueryMode.completedToday:
        return repo.fetchCalls(
          date: todayYmdSeoul(),
          completedOnly: true,
          limit: 100,
          includeCallHistory: true,
        );
      case ListQueryMode.incompleteByDate:
        return repo.fetchCalls(
          date: widget.date ?? todayYmdSeoul(),
          incompleteOnly: true,
          limit: 100,
          includeCallHistory: true,
        );
    }
  }

  String get _title {
    switch (widget.mode) {
      case ListQueryMode.today:
        return '오늘 통화';
      case ListQueryMode.incomplete:
        return '미통화';
      case ListQueryMode.recent:
        return '최근 통화';
      case ListQueryMode.completedToday:
        return '오늘 완료';
      case ListQueryMode.incompleteByDate:
        if (widget.date == todayYmdSeoul()) {
          return '오늘 미통화';
        }
        return '${widget.date?.substring(5) ?? ''} 미통화';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<List<SalesCall>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(koreanErrorMessage(snap.error!)),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _future = _load());
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('목록이 비어 있습니다.'));
          }

          // Group by assignedTo
          final Map<String, List<SalesCall>> grouped = {};
          for (var c in items) {
            final assignee = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
            grouped.putIfAbsent(assignee, () => []).add(c);
          }
          final keys = grouped.keys.toList()..sort((a, b) {
            if (a == '미지정') return 1;
            if (b == '미지정') return -1;
            return a.compareTo(b);
          });

          final List<dynamic> flattened = [];
          for (final assignee in keys) {
            flattened.add(assignee);
            flattened.addAll(grouped[assignee]!);
          }

          Color getColorForAssignee(String assignee, ColorScheme scheme) {
            if (assignee == '미지정') return scheme.surfaceContainerHighest;
            final colors = [
              Colors.blue.shade100,
              Colors.red.shade100,
              Colors.green.shade100,
              Colors.orange.shade100,
              Colors.purple.shade100,
              Colors.teal.shade100,
            ];
            return colors[assignee.hashCode % colors.length];
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.builder(
              itemCount: flattened.length,
              itemBuilder: (context, i) {
                final item = flattened[i];
                if (item is String) { // Header
                   final color = getColorForAssignee(item, Theme.of(context).colorScheme);
                   return Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     color: color,
                     child: Text(
                       '$item (${grouped[item]!.length})',
                       style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                     ),
                   );
                } else if (item is SalesCall) { // Item
                  final c = item;
                  String timeStr = '${c.callDate ?? ''} ${c.callTime ?? ''}'.trim();
                if (c.createdAt != null && c.createdAt!.isNotEmpty) {
                  final parsedDt = DateTime.tryParse(c.createdAt!);
                  if (parsedDt != null) {
                    final kstDt = parsedDt.toUtc().add(const Duration(hours: 9));
                    final mo = kstDt.month.toString().padLeft(2, '0');
                    final d = kstDt.day.toString().padLeft(2, '0');
                    final h = kstDt.hour.toString().padLeft(2, '0');
                    final min = kstDt.minute.toString().padLeft(2, '0');
                    timeStr = '${kstDt.year}-$mo-$d $h:$min';
                  }
                }

                  final scheme = Theme.of(context).colorScheme;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SalesCallDetailScreen(
                                id: c.id,
                                initial: c,
                              ),
                            ),
                          );
                          if (mounted) setState(() => _future = _load());
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    c.customerName ?? '(이름 없음)',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    timeStr,
                                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.phone_android, size: 14, color: scheme.primary),
                                  const SizedBox(width: 4),
                                  Text(c.customerPhone ?? '번호 없음', style: const TextStyle(fontSize: 14)),
                                  const Spacer(),
                                  if (c.statusLabel != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c.statusLabel!,
                                        style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer),
                                      ),
                                    ),
                                ],
                              ),
                              if (c.inquiryContent != null && c.inquiryContent!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  c.inquiryContent!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );
  }
}
