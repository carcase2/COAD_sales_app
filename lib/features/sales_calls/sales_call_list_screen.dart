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
  String _selectedAssignee = '전체';

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
          excludeSimpleInquiries: true,
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

  Color _colorForAssignee(String assignee, ColorScheme scheme) {
    if (assignee == '미지정') return scheme.surfaceContainerHighest;
    final colors = [
      Colors.blue.shade100,
      Colors.red.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
      Colors.purple.shade100,
      Colors.teal.shade100,
    ];
    return colors[assignee.hashCode.abs() % colors.length];
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

          // 1. Calculate counts per assignee
          final Map<String, int> counts = {'전체': items.length};
          for (var c in items) {
            final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
            counts[a] = (counts[a] ?? 0) + 1;
          }

          // 2. Sort assignees by count descending (keep '전체' at the front)
          final sortedAssignees = counts.keys.toList()..sort((a, b) {
            if (a == '전체') return -1;
            if (b == '전체') return 1;
            
            // Sort by count descending
            final countA = counts[a] ?? 0;
            final countB = counts[b] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            
            // If count is same, sort alphabetically
            return a.compareTo(b);
          });

          // Filter items based on selected assignee
          final filteredItems = _selectedAssignee == '전체'
              ? items
              : items.where((c) {
                  final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
                  return a == _selectedAssignee;
                }).toList();

          return Column(
            children: [
              // ─── 상단 담당자 필터 바 (건수 포함 및 정렬 적용) ───
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3))),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  itemCount: sortedAssignees.length,
                  itemBuilder: (context, idx) {
                    final assignee = sortedAssignees[idx];
                    final count = counts[assignee] ?? 0;
                    final isSelected = _selectedAssignee == assignee;
                    final color = _colorForAssignee(assignee, Theme.of(context).colorScheme);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedAssignee = assignee),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : color.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                assignee,
                                style: TextStyle(
                                  color: isSelected ? Colors.black87 : Colors.black54,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.5) : color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.black87 : Colors.black45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ─── 하단 목록 (디자인 개선) ───
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = _load());
                    await _future;
                  },
                  child: filteredItems.isEmpty
                      ? const Center(child: Text('해당 담당자의 목록이 없습니다.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, i) {
                            final c = filteredItems[i];
                            // ... 시간 계산 로직 ...
                            String timeStr = '${c.callDate ?? ''} ${c.callTime ?? ''}'.trim();
                            if (c.createdAt != null && c.createdAt!.isNotEmpty) {
                              final parsedDt = DateTime.tryParse(c.createdAt!);
                              if (parsedDt != null) {
                                final kstDt = parsedDt.toUtc().add(const Duration(hours: 9));
                                timeStr = '${kstDt.month}/${kstDt.day} ${kstDt.hour}:${kstDt.minute.toString().padLeft(2, '0')}';
                              }
                            }

                            final scheme = Theme.of(context).colorScheme;
                            final assignColor = _colorForAssignee(c.assignedTo ?? '미지정', scheme);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SalesCallDetailScreen(id: c.id, initial: c),
                                    ),
                                  );
                                  if (mounted) setState(() => _future = _load());
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.customerName ?? '(이름 없음)',
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Text(
                                            timeStr,
                                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.phone_android, size: 14, color: scheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            c.customerPhone ?? '번호 없음',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                          const Spacer(),
                                          if (c.callStage != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: scheme.secondaryContainer.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('${c.callStage}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      if (c.inquiryContent != null && c.inquiryContent!.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: scheme.surfaceContainerHighest.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            c.inquiryContent!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.4),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: assignColor.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.person, size: 12, color: assignColor.withOpacity(0.8)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (c.statusLabel != null)
                                            Text(
                                              c.statusLabel!,
                                              style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
