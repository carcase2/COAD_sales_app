import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_hub_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
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
  });

  final ListQueryMode mode;
  final String? date;
  /// [ListQueryMode.dateRange]·[ListQueryMode.followRange]에서 사용.
  final String? dateEndInclusive;
  final String? initialAssignee;
  /// [SalesCallDayFollowPagerScreen] 등 상위 Scaffold 안에 넣을 때 true.
  final bool embedded;

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
  bool _quickActionsOpen = false;
  final ScrollController _quickActionsScrollCtrl = ScrollController();
  bool _quickHasMoreAbove = false;
  bool _quickHasMoreBelow = false;

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
    _quickActionsScrollCtrl.dispose();
    super.dispose();
  }

  void _refreshQuickHints() {
    if (!_quickActionsOpen || !_quickActionsScrollCtrl.hasClients) {
      if (_quickHasMoreAbove || _quickHasMoreBelow) {
        setState(() {
          _quickHasMoreAbove = false;
          _quickHasMoreBelow = false;
        });
      }
      return;
    }
    final pos = _quickActionsScrollCtrl.position;
    final nextAbove = pos.pixels > 1;
    final nextBelow = pos.pixels < (pos.maxScrollExtent - 1);
    if (nextAbove != _quickHasMoreAbove || nextBelow != _quickHasMoreBelow) {
      setState(() {
        _quickHasMoreAbove = nextAbove;
        _quickHasMoreBelow = nextBelow;
      });
    }
  }

  /// 캐시를 먼저 보여주고 서버 데이터를 가져오는 핵심 로직
  Future<void> _loadWithCache() async {
    final repo = ref.read(salesCallsRepositoryProvider);
    
    // 1. 로컬 캐시 먼저 로드 (즉시 응답)
    // 날짜 팔로우는 next_scheduled_date 기준이라 call_date 캐시와 맞지 않아 사용하지 않음.
    if (widget.mode != ListQueryMode.incompleteByDate &&
        widget.mode != ListQueryMode.dateRange &&
        widget.mode != ListQueryMode.followRange) {
      try {
        final cacheDate = switch (widget.mode) {
          ListQueryMode.today => widget.date ?? todayYmdSeoul(),
          ListQueryMode.completedToday => widget.date ?? todayYmdSeoul(),
          ListQueryMode.incomplete => widget.date,
          ListQueryMode.recent => null,
          ListQueryMode.incompleteByDate => null,
          ListQueryMode.dateRange => null,
          ListQueryMode.followRange => null,
        };
        final cacheIncompleteOnly = widget.mode == ListQueryMode.incomplete;

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
          date: widget.date ?? todayYmdSeoul(),
          limit: 100,
          includeCallHistory: true,
        );
      case ListQueryMode.incomplete:
        if (widget.date != null && widget.dateEndInclusive != null) {
          return repo.fetchCallsAllPages(
            dateRangeStart: widget.date!,
            dateRangeEndInclusive: widget.dateEndInclusive!,
            uncalledOnly: true,
            includeCallHistory: true,
          );
        }
        return repo.fetchCallsAllPages(
          date: widget.date, // 날짜가 전달된 경우 해당 날짜만 (오늘 요약 클릭 시), 없으면 전체 (전체 랭킹 등)
          uncalledOnly: true,
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
          date: widget.date ?? todayYmdSeoul(),
          completedOnly: true,
          limit: 100,
          includeCallHistory: true,
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
          includeCallHistory: true,
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
        return '오늘 통화';
      case ListQueryMode.incomplete:
        if (widget.date != null && widget.dateEndInclusive != null) {
          return '미통화 ${widget.date} ~ ${widget.dateEndInclusive}';
        }
        if (widget.date == todayYmdSeoul()) {
          return '금일 미통화';
        }
        return '미통화';
      case ListQueryMode.recent:
        return '최근 통화';
      case ListQueryMode.completedToday:
        return '오늘 완료';
      case ListQueryMode.incompleteByDate:
        if (widget.date == todayYmdSeoul()) {
          return '오늘 날짜 팔로우';
        }
        return '${widget.date?.substring(5) ?? ''} 날짜 팔로우';
      case ListQueryMode.dateRange:
        return '접수 ${widget.date ?? ''} ~ ${widget.dateEndInclusive ?? ''}';
      case ListQueryMode.followRange:
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

  DateTime? _parseCreatedLocal(SalesCall c) {
    final raw = c.createdAt;
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    return dt.toLocal();
  }

  String _elapsedLabelSince(DateTime? createdLocal) {
    if (createdLocal == null) return '';
    final diff = DateTime.now().difference(createdLocal);
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

  String _stageLabelForCard(SalesCall c) {
    final raw = (c.callStage ?? '').trim();
    if (RegExp(r'^\d+$').hasMatch(raw)) return '${raw}차';
    if (raw.isEmpty || raw == '0' || raw == '접수') return '1차';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final actionsBottom = 12.0 + safeBottom;
    final quickMenuWidth = (screenWidth * 0.64).clamp(220.0, 300.0);
    final quickActions = <_QuickActionItem>[
      _QuickActionItem(
        label: '홈',
        subtitle: '업무 흐름·미통화·달력',
        color: Colors.blueGrey.shade700,
        icon: Icons.home_rounded,
        onTap: () {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          openHomeHub(context, ref);
        },
      ),
      _QuickActionItem(
        label: '접수',
        subtitle: '새 고객 전화 접수 등록',
        color: scheme.tertiary,
        icon: Icons.add_ic_call_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: kSalesCallCreateRouteName),
              builder: (_) => const SalesCallCreateScreen(),
            ),
          );
        },
      ),
      _QuickActionItem(
        label: '발행요청 (테스트중)',
        subtitle: '세금/이행 발급요청 확인',
        color: Colors.indigo.shade600,
        icon: Icons.receipt_long_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const IssuanceRequestScreen(),
            ),
          );
        },
      ),
      _QuickActionItem(
        label: '견적기 (테스트중)',
        subtitle: '견적서 작성 화면 열기',
        color: Colors.teal.shade600,
        icon: Icons.calculate_rounded,
        onTap: () async {
          setState(() => _quickActionsOpen = false);
          _refreshQuickHints();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('견적기 (테스트중)')),
                body: const QuoterHubScreen(),
              ),
            ),
          );
        },
      ),
    ];

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
      body: Stack(
        children: [
          _buildBody(),
          if (_quickActionsOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _quickActionsOpen = false),
                child: const SizedBox.expand(),
              ),
            ),
          Positioned(
            right: 16,
            bottom: actionsBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_quickActionsOpen)
                  Container(
                    width: quickMenuWidth,
                    constraints: const BoxConstraints(maxHeight: 300),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (_quickHasMoreAbove)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text('위에 메뉴 더 있음', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              _refreshQuickHints();
                              return false;
                            },
                            child: SingleChildScrollView(
                              controller: _quickActionsScrollCtrl,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                children: quickActions
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Material(
                                          color: item.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: item.onTap,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Icon(item.icon, size: 18, color: item.color),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          item.label,
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          softWrap: false,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color:
                                                                scheme.onSurface,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          item.subtitle,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          softWrap: false,
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: scheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(Icons.chevron_right_rounded, size: 18, color: scheme.onSurfaceVariant),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                        if (_quickHasMoreBelow)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text('아래 메뉴 더 있음', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                FloatingActionButton(
                  heroTag: 'list_actions_toggle',
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  mini: true,
                  onPressed: () {
                    setState(() => _quickActionsOpen = !_quickActionsOpen);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuickHints());
                  },
                  tooltip: _quickActionsOpen ? '닫기' : '열기',
                  child: Icon(_quickActionsOpen ? Icons.close_rounded : Icons.menu_open_rounded),
                ),
              ],
            ),
          ),
        ],
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
    final overrides = ref.watch(tempManagerOverridesProvider).valueOrNull ?? const [];
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

          final Map<String, int> counts = {'전체': items.length};
          for (var c in items) {
            final a = _assigneeForMode(c, overrides);
            counts[a] = (counts[a] ?? 0) + 1;
          }

          final sortedAssignees = counts.keys.toList()..sort((a, b) {
            if (a == '전체') return -1;
            if (b == '전체') return 1;
            
            final countA = counts[a] ?? 0;
            final countB = counts[b] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            
            return a.compareTo(b);
          });

          // 전달받은/자동 선택 담당자가 현재 목록에 없으면 빈 결과가 되므로 '전체'로 보정
          if (!sortedAssignees.contains(_selectedAssignee)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_selectedAssignee != '전체') {
                setState(() => _selectedAssignee = '전체');
              }
            });
          }

          final user = ref.watch(authControllerProvider);
          final userName = user?.name;
          // 날짜 팔로우: 로그인명 자동 선택 시 전체 건수와 칩 필터가 어긋나 0건으로 보일 수 있음 → 비활성화
          if (widget.mode != ListQueryMode.incompleteByDate &&
              widget.mode != ListQueryMode.followRange &&
              widget.initialAssignee == null &&
              _selectedAssignee == '전체' &&
              userName != null &&
              counts.containsKey(userName)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedAssignee == '전체') {
                setState(() => _selectedAssignee = userName);
              }
            });
          }

          if (widget.initialAssignee != null && widget.initialAssignee != '전체' && !_hasScrolledToInitial) {
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

          final filteredItems = items.where((c) {
            final a = _assigneeForMode(c, overrides);
            bool matchesAssignee = _selectedAssignee == '전체' || a == _selectedAssignee;
            
            bool matchesSearch = true;
            if (_searchQuery.isNotEmpty) {
              final queryTerms =
                  _searchQuery.toLowerCase().split(' ').where((t) => t.isNotEmpty);
              if (queryTerms.isNotEmpty) {
                matchesSearch = queryTerms.every(
                  (term) => termMatchesSalesCallSearch(
                    term,
                    customerName: c.customerName,
                    customerPhone: c.customerPhone,
                    inquiryContent: c.inquiryContent,
                    regionLabel: c.regionLabel,
                    productCategoryName: c.productCategoryName,
                    extra: c.regionManager,
                  ),
                );
              }
            }
            
            return matchesAssignee && matchesSearch;
          }).toList();

          return Column(
            children: [
              Container(
                height: 58,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: sortedAssignees.length,
                  itemBuilder: (context, idx) {
                    final assignee = sortedAssignees[idx];
                    final count = counts[assignee] ?? 0;
                    final isSelected = _selectedAssignee == assignee;
                    final color = _colorForAssignee(assignee, Theme.of(context).colorScheme);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedAssignee = assignee);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, i) {
                            final c = filteredItems[i];
                            String timeStr = '${c.callDate ?? ''} ${c.callTime ?? ''}'.trim();
                            DateTime? createdLocal;
                            if (c.createdAt != null && c.createdAt!.isNotEmpty) {
                              createdLocal = _parseCreatedLocal(c);
                              if (createdLocal != null) {
                                timeStr = '${createdLocal.month}/${createdLocal.day} ${createdLocal.hour}:${createdLocal.minute.toString().padLeft(2, '0')}';
                              }
                            }
                            final elapsedLabel = _elapsedLabelSince(createdLocal);
                            final showElapsed = c.isMissed && elapsedLabel.isNotEmpty;
                            final stageLabel = _stageLabelForCard(c);
                            final scheme = Theme.of(context).colorScheme;
                            final displayAssignee = _assigneeForMode(c, overrides);
                            final assignColor = _colorForAssignee(displayAssignee, scheme);

                            return Container(
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
                                      if (showElapsed) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: scheme.errorContainer.withOpacity(0.55),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '접수 후 $elapsedLabel',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: scheme.onErrorContainer,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
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
                                          // Stage Badge
                                          if (c.callStage != null && c.callStage!.isNotEmpty)
                                            _buildPill(
                                              (RegExp(r'^\d+$').hasMatch(c.callStage ?? '')) 
                                                ? '${c.callStage}차' 
                                                : (c.callStage ?? '접수'), 
                                              scheme.secondaryContainer, 
                                              scheme.onSecondaryContainer
                                            ),
                                          const SizedBox(width: 8),
                                          // Status Badge
                                          if (c.statusLabel != null)
                                            _buildPill(c.statusLabel!, scheme.primaryContainer, scheme.onPrimaryContainer, isBold: true),
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

class _QuickActionItem {
  const _QuickActionItem({
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
}
