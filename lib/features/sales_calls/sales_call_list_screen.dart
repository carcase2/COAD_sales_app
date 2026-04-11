import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListQueryMode { today, incomplete, recent, completedToday, incompleteByDate }

class SalesCallListScreen extends ConsumerStatefulWidget {
  const SalesCallListScreen({super.key, required this.mode, this.date, this.initialAssignee});

  final ListQueryMode mode;
  final String? date;
  final String? initialAssignee;

  @override
  ConsumerState<SalesCallListScreen> createState() => _SalesCallListScreenState();
}

class _SalesCallListScreenState extends ConsumerState<SalesCallListScreen> {
  List<SalesCall> _items = [];
  bool _isLoading = true;
  Object? _error;
  
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  String _selectedAssignee = '전체';
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToInitial = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAssignee != null) {
      _selectedAssignee = widget.initialAssignee!;
    }
    _loadWithCache();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 캐시를 먼저 보여주고 서버 데이터를 가져오는 핵심 로직
  Future<void> _loadWithCache() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    
    // 1. 로컬 캐시 먼저 로드 (즉시 응답)
    try {
      final cached = await repo.fetchCachedCalls(
        date: widget.mode == ListQueryMode.recent ? null : (widget.date ?? todayYmdSeoul()),
        incompleteOnly: widget.mode == ListQueryMode.incomplete || widget.mode == ListQueryMode.incompleteByDate,
      );
      
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _items = cached;
          _isLoading = false; // 캐시가 있으면 일단 로딩 종료 표시
        });
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }

    // 2. 서버에서 최신 데이터 가져오기
    try {
      if (_items.isEmpty) {
        setState(() => _isLoading = true);
      }
      
      final remote = await _fetchRemote(repo);
      
      if (mounted) {
        setState(() {
          _items = remote;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 캐시가 아예 없는 경우에만 에러 화면 표시
          if (_items.isEmpty) {
            _error = e;
          }
        });
        
        // 캐시가 있는 상태에서 서버 에러면 스낵바로만 알림
        if (_items.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('최신 데이터를 가져오지 못했습니다: ${koreanErrorMessage(e)}')),
          );
        }
      }
    }
  }

  Future<List<SalesCall>> _fetchRemote(SalesCallsRepository repo) {
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
    // ... 기존 코드와 동일 ...
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
    // ... 기존 코드와 동일 ...
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
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchField()
          : Text(_title),
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchCtrl.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (_isLoading && _items.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: '고객명, 연락처, 상호명 검색...',
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: 14),
      ),
      style: const TextStyle(fontSize: 16),
      onChanged: (val) {
        setState(() => _searchQuery = val.trim());
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(koreanErrorMessage(_error!)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadWithCache,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _items;
    if (items.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 56, color: scheme.outlineVariant),
              const SizedBox(height: 16),
              const Text('목록이 비어 있습니다.'),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadWithCache, child: const Text('새로고침')),
            ],
          ),
        ),
      );
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

          // 2-1. Smart default: filter by logged-in user if no initialAssignee was provided
          final user = ref.watch(authControllerProvider);
          final userName = user?.name;
          if (widget.initialAssignee == null &&
              _selectedAssignee == '전체' &&
              userName != null &&
              counts.containsKey(userName)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedAssignee == '전체') {
                setState(() => _selectedAssignee = userName);
              }
            });
          }

          // Auto-scroll to selected assignee on first load
          if (widget.initialAssignee != null && widget.initialAssignee != '전체' && !_hasScrolledToInitial) {
            final idx = sortedAssignees.indexOf(widget.initialAssignee!);
            if (idx != -1) {
              _hasScrolledToInitial = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  // Approximate width per item (padding 12 + approx text + count badge)
                  // Let's use jumpTo or animateTo with an estimated position
                  double offset = idx * 90.0; // Estimated width
                  _scrollController.animateTo(
                    offset,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutQuart,
                  );
                }
              });
            }
          }

          // Filter items based on selected assignee AND search query
          final filteredItems = items.where((c) {
            // 1. Assignee Filter
            final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
            bool matchesAssignee = _selectedAssignee == '전체' || a == _selectedAssignee;
            
            // 2. Search Filter
            bool matchesSearch = true;
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final name = (c.customerName ?? '').toLowerCase();
              final phone = (c.customerPhone ?? '').toLowerCase();
              final company = (c.company ?? '').toLowerCase();
              matchesSearch = name.contains(query) || phone.contains(query) || company.contains(query);
            }
            
            return matchesAssignee && matchesSearch;
          }).toList();

          return Column(
            children: [
              // ─── 상단 담당자 필터 바 (건수 포함 및 정렬 적용) ───
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
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
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                    await _loadWithCache();
                  },
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '해당 담당자의 목록이 없습니다.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
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
                                  if (mounted) _loadWithCache(); // 복귀 시 캐시+원격 동기화 재실행
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
                                          if (c.images.isNotEmpty) ...[
                                            Tooltip(
                                              message: '첨부 ${c.images.length}개',
                                              child: Icon(
                                                Icons.attach_file,
                                                size: 18,
                                                color: scheme.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
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
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
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
  }
}
