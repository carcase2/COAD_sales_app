import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_display.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_search_delegate.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ListQueryMode {
  today,
  incomplete,
  /// 최근 N일 미해결 미통화 — [date]는 `fromDate`(yyyy-MM-dd).
  pendingUncalled,
  recent,
  completedToday,
  incompleteByDate,
  /// 접수일 `call_date` 구간 (양끝 포함). [date]·[dateEndInclusive] 필수.
  dateRange,
  /// `next_scheduled_date` 팔로우 구간 (양끝 포함). [date]·[dateEndInclusive] 필수.
  followRange,
}

class SalesCallListScreen extends ConsumerStatefulWidget {
  const SalesCallListScreen({
    super.key,
    required this.mode,
    this.date,
    this.dateEndInclusive,
    this.initialAssignee,
    this.embedded = false,
    this.selectedAssignee,
    this.onAssigneeChanged,
    this.assigneeScrollNonce,
  });

  final ListQueryMode mode;
  final String? date;
  /// [ListQueryMode.dateRange]·[ListQueryMode.followRange]에서 사용.
  final String? dateEndInclusive;
  final String? initialAssignee;
  /// [SalesCallDayFollowPagerScreen] 등 상위 Scaffold 안에 넣을 때 true.
  final bool embedded;
  /// 달력 팔로우 페이저 등에서 날짜 스와이프 시 담당자 필터 유지.
  final String? selectedAssignee;
  final ValueChanged<String>? onAssigneeChanged;
  /// 페이저 날짜·담당자 변경 시 담당자 칩이 보이도록 가로 스크롤.
  final int? assigneeScrollNonce;

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
  String _debouncedSearchQuery = '';
  Timer? _searchDebounce;

  String _selectedAssignee = '전체';
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToInitial = false;
  int? _lastHandledAssigneeScrollNonce;
  bool _pendingSharedAssigneeScroll = false;
  bool _mineOnlyFilter = false;

  List<SalesCall>? _memoItems;
  String? _memoAssignee;
  String? _memoSearch;
  int? _memoOverridesLen;
  Map<String, int>? _memoCounts;
  List<String>? _memoSortedAssignees;
  List<SalesCall>? _memoFilteredItems;

  bool get _sharedAssigneeFilter => widget.onAssigneeChanged != null;

  String get _activeAssignee => widget.selectedAssignee ?? _selectedAssignee;

  void _updateAssignee(String assignee) {
    if (widget.onAssigneeChanged != null) {
      widget.onAssigneeChanged!(assignee);
    } else {
      setState(() => _selectedAssignee = assignee);
    }
  }

  void _scrollActiveAssigneeChipIntoView(List<String> sortedAssignees) {
    final assignee = _activeAssignee;
    if (assignee == '전체') return;
    final idx = sortedAssignees.indexOf(assignee);
    if (idx < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const chipStride = 96.0;
      final viewport = _scrollController.position.viewportDimension;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final chipStart = idx * chipStride;
      final chipEnd = chipStart + chipStride;
      final current = _scrollController.offset;
      double target = current;
      if (chipStart < current) {
        target = chipStart;
      } else if (chipEnd > current + viewport) {
        target = chipEnd - viewport;
      } else {
        return;
      }
      _scrollController.animateTo(
        target.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _markSharedAssigneeScrollPending() {
    if (!_sharedAssigneeFilter) return;
    _pendingSharedAssigneeScroll = true;
  }

  @override
  void didUpdateWidget(SalesCallListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nonce = widget.assigneeScrollNonce;
    if (nonce != null && nonce != _lastHandledAssigneeScrollNonce) {
      _lastHandledAssigneeScrollNonce = nonce;
      _markSharedAssigneeScrollPending();
    } else if (_sharedAssigneeFilter &&
        oldWidget.selectedAssignee != widget.selectedAssignee) {
      _markSharedAssigneeScrollPending();
    }
  }

  /// 「내 건만」 보기 — 화면 재진입 시에도 유지되는 사용자 선호.
  static const _mineOnlyPrefKey = 'sales_list_mine_only_v1';

  @override
  void initState() {
    super.initState();
    if (widget.initialAssignee != null) {
      _selectedAssignee = widget.initialAssignee!;
    } else if (!_sharedAssigneeFilter) {
      _restoreMineOnlyPreference();
    }
    if (widget.assigneeScrollNonce != null) {
      _lastHandledAssigneeScrollNonce = widget.assigneeScrollNonce;
      _markSharedAssigneeScrollPending();
    }
    _loadWithCache();
  }

  void _restoreMineOnlyPreference() {
    final prefs = ref.read(appDependenciesProvider).prefs;
    if (prefs.getBool(_mineOnlyPrefKey) != true) return;
    final userName = ref.read(authControllerProvider)?.name.trim();
    if (userName == null || userName.isEmpty) return;
    _mineOnlyFilter = true;
    _selectedAssignee = userName;
  }

  void _saveMineOnlyPreference(bool value) {
    unawaited(
      ref.read(appDependenciesProvider).prefs.setBool(_mineOnlyPrefKey, value),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final trimmed = val.trim();
    setState(() => _searchQuery = trimmed);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_debouncedSearchQuery == trimmed) return;
      setState(() => _debouncedSearchQuery = trimmed);
    });
  }

  ({
    Map<String, int> counts,
    List<String> sortedAssignees,
    List<SalesCall> filteredItems,
  }) _resolveListData(
    List<SalesCall> items,
    List<TempManagerOverride> overrides,
  ) {
    final activeAssignee = _activeAssignee;
    if (identical(_memoItems, items) &&
        _memoAssignee == activeAssignee &&
        _memoSearch == _debouncedSearchQuery &&
        _memoOverridesLen == overrides.length &&
        _memoCounts != null &&
        _memoSortedAssignees != null &&
        _memoFilteredItems != null) {
      return (
        counts: _memoCounts!,
        sortedAssignees: _memoSortedAssignees!,
        filteredItems: _memoFilteredItems!,
      );
    }

    final counts = <String, int>{'전체': items.length};
    for (final c in items) {
      final a = _assigneeForMode(c, overrides);
      counts[a] = (counts[a] ?? 0) + 1;
    }

    if (_sharedAssigneeFilter &&
        activeAssignee != '전체' &&
        !counts.containsKey(activeAssignee)) {
      counts[activeAssignee] = 0;
    }

    final sortedAssignees = counts.keys.toList()
      ..sort((a, b) {
        if (a == '전체') return -1;
        if (b == '전체') return 1;

        final countA = counts[a] ?? 0;
        final countB = counts[b] ?? 0;
        if (countA != countB) return countB.compareTo(countA);

        return a.compareTo(b);
      });

    final filteredItems = items.where((c) {
      final a = _assigneeForMode(c, overrides);
      final matchesAssignee =
          activeAssignee == '전체' || a == activeAssignee;

      if (_debouncedSearchQuery.isEmpty) {
        return matchesAssignee;
      }

      final queryTerms = _debouncedSearchQuery
          .toLowerCase()
          .split(' ')
          .where((t) => t.isNotEmpty);
      if (queryTerms.isEmpty) return matchesAssignee;

      final matchesSearch = queryTerms.every(
        (term) => termMatchesSalesCallSearch(
          term,
          customerName: c.customerName,
          customerPhone: c.customerPhone,
          inquiryContent: c.inquiryContent,
          regionLabel: c.regionLabel,
          productCategoryName: c.productCategoryName,
          extra: c.assignedTo,
        ),
      );
      return matchesAssignee && matchesSearch;
    }).toList();

    _memoItems = items;
    _memoAssignee = activeAssignee;
    _memoSearch = _debouncedSearchQuery;
    _memoOverridesLen = overrides.length;
    _memoCounts = counts;
    _memoSortedAssignees = sortedAssignees;
    _memoFilteredItems = filteredItems;

    return (
      counts: counts,
      sortedAssignees: sortedAssignees,
      filteredItems: filteredItems,
    );
  }

  /// 캐시를 먼저 보여주고 서버 데이터를 가져오는 핵심 로직
  Future<void> _loadWithCache() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    
    // 1. 로컬 캐시 먼저 로드 (즉시 응답)
    // 날짜 팔로우는 next_scheduled_date 기준이라 call_date 캐시와 맞지 않아 사용하지 않음.
    if (widget.mode != ListQueryMode.incompleteByDate &&
        widget.mode != ListQueryMode.dateRange &&
        widget.mode != ListQueryMode.followRange &&
        widget.mode != ListQueryMode.pendingUncalled) {
      try {
        final cacheDate = switch (widget.mode) {
          ListQueryMode.today => widget.date ?? todayYmdSeoul(),
          ListQueryMode.completedToday => widget.date ?? todayYmdSeoul(),
          ListQueryMode.incomplete => widget.date,
          ListQueryMode.pendingUncalled => widget.date,
          ListQueryMode.recent => null,
          ListQueryMode.incompleteByDate => null,
          ListQueryMode.dateRange => null,
          ListQueryMode.followRange => null,
        };
        final cacheIncompleteOnly = widget.mode == ListQueryMode.incomplete ||
            widget.mode == ListQueryMode.pendingUncalled;

        final cached = await repo.fetchCachedCalls(
          date: cacheDate,
          incompleteOnly: cacheIncompleteOnly,
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
    }

    // 2. 서버에서 최신 데이터 가져오기
    try {
      if (_items.isEmpty) {
        setState(() => _isLoading = true);
      }
      
      final remote = await _fetchRemote(repo);
      
      if (mounted) {
        if (_sharedAssigneeFilter && _activeAssignee != '전체') {
          _markSharedAssigneeScrollPending();
        }
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
        // 하루치 전체 — limit 100이면 대량 접수일에 조용히 누락됨.
        return repo.fetchCallsAllPages(
          date: widget.date ?? todayYmdSeoul(),
          includeCallHistory: false,
        );
      case ListQueryMode.incomplete:
        if (widget.date != null && widget.dateEndInclusive != null) {
          return repo.fetchCallsAllPages(
            dateRangeStart: widget.date!,
            dateRangeEndInclusive: widget.dateEndInclusive!,
            uncalledOnly: true,
            includeCallHistory: false,
          );
        }
        return repo.fetchCallsAllPages(
          date: widget.date, // 날짜가 전달된 경우 해당 날짜만 (오늘 요약 클릭 시), 없으면 전체 (전체 랭킹 등)
          uncalledOnly: true,
          includeCallHistory: false,
        );
      case ListQueryMode.pendingUncalled:
        return repo.fetchCallsAllPages(
          fromDate: widget.date ?? pendingUncalledFromYmd(todayYmdSeoul()),
          uncalledOnly: true,
          includeCallHistory: false,
        );
      case ListQueryMode.recent:
        return repo.fetchCalls(
          limit: 50,
          offset: 0,
          includeCallHistory: false,
        );
      case ListQueryMode.completedToday:
        return repo.fetchCallsAllPages(
          date: widget.date ?? todayYmdSeoul(),
          completedOnly: true,
          includeCallHistory: false,
        );
      case ListQueryMode.incompleteByDate:
        return repo.fetchCallsAllPages(
          followDate: widget.date ?? todayYmdSeoul(),
          incompleteOnly: true,
          excludeSimpleInquiries: true,
          // `todayFollowOverviewProvider`·홈 바텀시트와 동일 조건 (call_history 포함 시 일부 행 누락 가능)
          includeCallHistory: false,
        );
      case ListQueryMode.dateRange:
        return repo.fetchCallsAllPages(
          dateRangeStart: widget.date!,
          dateRangeEndInclusive: widget.dateEndInclusive!,
          includeCallHistory: false,
        );
      case ListQueryMode.followRange:
        return repo.fetchCallsAllPages(
          followRangeStart: widget.date!,
          followRangeEndInclusive: widget.dateEndInclusive!,
          incompleteOnly: true,
          excludeSimpleInquiries: true,
          includeCallHistory: false,
        );
    }
  }

  String get _title {
    switch (widget.mode) {
      case ListQueryMode.today:
        return '오늘 접수';
      case ListQueryMode.incomplete:
        if (widget.date != null && widget.dateEndInclusive != null) {
          return '미통화 ${widget.date} ~ ${widget.dateEndInclusive}';
        }
        if (widget.date == todayYmdSeoul()) {
          return '금일 미통화';
        }
        if (widget.date == addDaysToYmd(todayYmdSeoul(), -1)) {
          return '전일 미통화';
        }
        return '미통화';
      case ListQueryMode.pendingUncalled:
        return '처리할 미통화';
      case ListQueryMode.recent:
        return '최근 통화';
      case ListQueryMode.completedToday:
        return '오늘 완료';
      case ListQueryMode.incompleteByDate:
        final followDate = widget.date ?? todayYmdSeoul();
        if (followDate == todayYmdSeoul()) {
          return '오늘 팔로우';
        }
        return '${formatYmdFlowLabelKo(followDate)} 팔로우';
      case ListQueryMode.dateRange:
        return '접수 ${widget.date ?? ''} ~ ${widget.dateEndInclusive ?? ''}';
      case ListQueryMode.followRange:
        if (widget.date != null && widget.dateEndInclusive != null) {
          final start = formatYmdFlowLabelKo(widget.date!);
          final end = formatYmdFlowLabelKo(widget.dateEndInclusive!);
          return '팔로우 $start ~ $end';
        }
        return '팔로우 ${widget.date ?? ''} ~ ${widget.dateEndInclusive ?? ''}';
    }
  }

  Color _colorForAssignee(String assignee, ColorScheme scheme) {
    if (assignee == '미지정') return scheme.outlineVariant;
    final colors = [
      Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.22),
        scheme.surfaceContainerLowest,
      ),
      Color.alphaBlend(
        scheme.secondary.withValues(alpha: 0.22),
        scheme.surfaceContainerLowest,
      ),
      Color.alphaBlend(
        scheme.tertiary.withValues(alpha: 0.22),
        scheme.surfaceContainerLowest,
      ),
      Color.alphaBlend(
        scheme.error.withValues(alpha: 0.18),
        scheme.surfaceContainerLowest,
      ),
      Color.alphaBlend(
        scheme.primaryContainer.withValues(alpha: 0.35),
        scheme.surfaceContainerLowest,
      ),
      Color.alphaBlend(
        scheme.secondaryContainer.withValues(alpha: 0.35),
        scheme.surfaceContainerLowest,
      ),
    ];
    return colors[assignee.hashCode.abs() % colors.length];
  }

  String _assigneeForMode(SalesCall c, List<TempManagerOverride> overrides) {
    return displayAssigneeForCall(c, overrides, DateTime.now());
  }

  /// 목록 맨 아래 여백 — 홈 인디케이터·우하단 FAB와 겹치지 않게.
  double _listScrollBottomInset() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const base = 24.0;
    if (widget.embedded) return base + safeBottom + 16;
    return base + safeBottom + 72;
  }

  DateTime? _receptionSeoul(SalesCall c) => resolveSalesCallReceptionSeoul(
        callDate: c.callDate,
        callTime: c.callTime,
        createdAt: c.createdAt,
      );

  String _elapsedLabelSince(DateTime? receptionSeoul) {
    if (receptionSeoul == null) return '';
    final diff = DateTime.now().difference(receptionSeoul);
    if (diff.isNegative) return '방금 접수';
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 경과';
    if (diff.inDays < 1) {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      if (mins == 0) return '${hours}시간 경과';
      return '${hours}시간 ${mins}분 경과';
    }
    return '${diff.inDays}일 경과';
  }

  Future<void> _openCreateShortcut() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SalesCallCreateScreen()),
    );
    if (created == true && mounted) {
      await _loadWithCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchField()
          : Text(_title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: '홈으로 이동',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SalesCallSearchDelegate(
                  initialItems: _items,
                  repository: ref.read(salesCallsRepositoryProvider),
                ),
              );
            },
            tooltip: '통화 내역 검색',
          ),
          if (_isLoading && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16, 
                height: 16, 
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            )
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateShortcut,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 접수'),
      ),
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

  Widget _buildEmbeddedSearchBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '고객명, 연락처 검색…',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색 지우기',
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchDebounce?.cancel();
                    setState(() {
                      _searchQuery = '';
                      _debouncedSearchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
      ),
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
    final overrides =
        ref.watch(tempManagerOverridesProvider).valueOrNull ?? const [];
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

          final listData = _resolveListData(items, overrides);
          final counts = listData.counts;
          final sortedAssignees = listData.sortedAssignees;
          final filteredItems = listData.filteredItems;
          final activeAssignee = _activeAssignee;

          // 전달받은/자동 선택 담당자가 현재 목록에 없으면 빈 결과가 되므로 '전체'로 보정
          if (!_sharedAssigneeFilter &&
              !sortedAssignees.contains(activeAssignee)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_activeAssignee != '전체') {
                _updateAssignee('전체');
              }
            });
          }

          final userName = ref.watch(
            authControllerProvider.select((u) => u?.name),
          );
          // 담당자 자동 필터 제거 — 기본은 전체, 「내 건만」 토글로 선택
          if (!_sharedAssigneeFilter &&
              widget.initialAssignee != null &&
              widget.initialAssignee != '전체' &&
              !_hasScrolledToInitial) {
            final idx = sortedAssignees.indexOf(widget.initialAssignee!);
            if (idx != -1) {
              _hasScrolledToInitial = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  double offset = idx * 90.0;
                  _scrollController.animateTo(
                    offset,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutQuart,
                  );
                }
              });
            }
          }

          if (_pendingSharedAssigneeScroll) {
            _pendingSharedAssigneeScroll = false;
            _scrollActiveAssigneeChipIntoView(sortedAssignees);
          }

          return Column(
            children: [
              if (widget.embedded) _buildEmbeddedSearchBar(),
              if (!_sharedAssigneeFilter &&
                  userName != null &&
                  userName.isNotEmpty &&
                  counts.containsKey(userName))
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: Text('내 건만 ($userName)'),
                      selected: _mineOnlyFilter,
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() => _mineOnlyFilter = selected);
                        _saveMineOnlyPreference(selected);
                        _updateAssignee(selected ? userName : '전체');
                      },
                    ),
                  ),
                ),
              Container(
                height: 64,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  clipBehavior: Clip.none,
                  itemCount: sortedAssignees.length,
                  itemBuilder: (context, idx) {
                    final assignee = sortedAssignees[idx];
                    final count = counts[assignee] ?? 0;
                    final isSelected = activeAssignee == assignee;
                    final color = _colorForAssignee(assignee, Theme.of(context).colorScheme);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          final mineOnly =
                              assignee != '전체' && assignee == userName;
                          setState(() => _mineOnlyFilter = mineOnly);
                          _saveMineOnlyPreference(mineOnly);
                          _updateAssignee(assignee);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ] : null,
                            border: Border.all(
                              color: isSelected ? Colors.transparent : color.withOpacity(0.2),
                              width: 1,
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
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLowest
                                          .withOpacity(0.7)
                                      : color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
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
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            _listScrollBottomInset(),
                          ),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, i) {
                            final c = filteredItems[i];
                            final isPendingMode =
                                widget.mode == ListQueryMode.pendingUncalled;
                            final todayYmd = todayYmdSeoul();
                            final receptionYmd = isPendingMode
                                ? salesCallReceptionYmd(c)
                                : '';
                            final isCarriedOver = isPendingMode &&
                                receptionYmd.isNotEmpty &&
                                receptionYmd != todayYmd;
                            final receptionSeoul = _receptionSeoul(c);
                            String timeStr = formatSalesCallReceptionShort(
                              callDate: c.callDate,
                              callTime: c.callTime,
                              createdAt: c.createdAt,
                            );
                            if (isPendingMode && receptionYmd.isNotEmpty) {
                              timeStr = '접수 $receptionYmd';
                            }
                            final elapsedLabel =
                                _elapsedLabelSince(receptionSeoul);
                            final showElapsed = c.isMissed && elapsedLabel.isNotEmpty;
                            final stageLabel = c.displayStageLabel;
                            final inquiryMethod = c.displayInquiryMethod;
                            final scheme = Theme.of(context).colorScheme;
                            final displayAssignee = _assigneeForMode(c, overrides);
                            final assignColor = _colorForAssignee(displayAssignee, scheme);

                            return Container(
                              key: ValueKey(c.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: assignColor.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SalesCallDetailScreen(id: c.id, initial: c),
                                    ),
                                  );
                                  if (mounted) _loadWithCache();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: assignColor.withValues(alpha: 0.9),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: SearchHighlightText(
                                              text: c.customerName ?? '(이름 없음)',
                                              query: _searchQuery,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            timeStr,
                                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withOpacity(0.55), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      if (showElapsed || isCarriedOver) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (isCarriedOver) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme.tertiaryContainer
                                                      .withOpacity(0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '이월',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: scheme
                                                        .onTertiaryContainer,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (showElapsed) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: scheme.errorContainer
                                                      .withOpacity(0.55),
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '접수 후 $elapsedLabel',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        scheme.onErrorContainer,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: scheme.secondaryContainer
                                                    .withOpacity(0.8),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '상담이력 $stageLabel',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: scheme
                                                      .onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: scheme.secondaryContainer.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '상담이력 $stageLabel',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: scheme.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),

                                      // NEW: Metadata Row (Region & Product)
                                      Row(
                                        children: [
                                          if (c.regionSido != null || c.regionName != null) ...[
                                            Icon(Icons.location_on_outlined, size: 14, color: scheme.onSurfaceVariant.withOpacity(0.6)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${c.regionSido != null ? '[${c.regionSido}] ' : ''}${c.regionName ?? ''}'.trim(),
                                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 12),
                                          if (c.productCategoryName != null) ...[
                                            Icon(Icons.inventory_2_outlined, size: 14, color: scheme.onSurfaceVariant.withOpacity(0.6)),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.productCategoryName!,
                                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      
                                      // Call & Quick Actions Bar
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SearchHighlightText(
                                              text: c.customerPhone ?? '번호 없음',
                                              query: _searchQuery,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: scheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Quick Actions
                                          _buildQuickAction(
                                            Icons.call,
                                            scheme.secondary,
                                            () => LauncherUtils.makePhoneCall(
                                              c.customerPhone ?? '',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildQuickAction(
                                            Icons.message_rounded,
                                            scheme.primary,
                                            () => LauncherUtils.sendSMS(
                                              c.customerPhone ?? '',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      if (c.inquiryContent != null && c.inquiryContent!.isNotEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(color: scheme.outlineVariant.withOpacity(0.5), width: 3),
                                            ),
                                          ),
                                          child: SearchHighlightText(
                                            text: c.inquiryContent!,
                                            query: _searchQuery,
                                            style: TextStyle(fontSize: 14, color: scheme.onSurface.withOpacity(0.8), height: 1.4),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 12),

                                      // Bottom Row: Assignee and Status/Stage
                                      Row(
                                        children: [
                                          // Assignee Tag (Takes available space and truncates if needed)
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: assignColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(radius: 4, backgroundColor: assignColor),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      displayAssignee,
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildPill(
                                            stageLabel,
                                            scheme.secondaryContainer,
                                            scheme.onSecondaryContainer,
                                          ),
                                          const SizedBox(width: 8),
                                          if (c.statusLabel != null)
                                            _buildPill(c.statusLabel!, scheme.primaryContainer, scheme.onPrimaryContainer, isBold: true),
                                          if (inquiryMethod != null) ...[
                                            const SizedBox(width: 8),
                                            _buildPill(
                                              inquiryMethod,
                                              scheme.tertiaryContainer,
                                              scheme.onTertiaryContainer,
                                            ),
                                          ],
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

  Widget _buildQuickAction(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _buildPill(String label, Color bgColor, Color textColor, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
