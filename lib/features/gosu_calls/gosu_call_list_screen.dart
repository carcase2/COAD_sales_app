import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/data/gosu_sales_calls_repository.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_create_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_detail_screen.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GosuWorkflowFilter { all, received, inProgress, closed, openFollow }

class GosuCallListScreen extends ConsumerStatefulWidget {
  const GosuCallListScreen({
    super.key,
    required this.mode,
    this.title,
    this.fromYmd,
    this.toYmdInclusive,
  });

  final GosuListMode mode;
  final String? title;
  final String? fromYmd;
  final String? toYmdInclusive;

  @override
  ConsumerState<GosuCallListScreen> createState() => _GosuCallListScreenState();
}

class _GosuCallListScreenState extends ConsumerState<GosuCallListScreen> {
  final _searchCtrl = TextEditingController();
  final _listController = ScrollController();
  List<GosuSalesCall> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;
  String _query = '';
  int _offset = 0;
  int _generation = 0;
  late GosuWorkflowFilter _workflowFilter;

  bool get _isAllCatalog => widget.mode == GosuListMode.all;

  bool get _hasWorkflowFilters => switch (widget.mode) {
    GosuListMode.todayReception ||
    GosuListMode.dateRange ||
    GosuListMode.todayUpdated ||
    GosuListMode.updatedRange ||
    GosuListMode.awaitingFollowUp ||
    GosuListMode.activeFollowUp ||
    GosuListMode.all => true,
    _ => false,
  };

  bool get _showInProgressFilter => switch (widget.mode) {
    GosuListMode.todayReception ||
    GosuListMode.dateRange ||
    GosuListMode.todayUpdated ||
    GosuListMode.updatedRange ||
    GosuListMode.awaitingFollowUp ||
    GosuListMode.activeFollowUp => true,
    _ => false,
  };

  bool get _showClosedFilter => switch (widget.mode) {
    GosuListMode.todayReception ||
    GosuListMode.dateRange ||
    GosuListMode.todayUpdated ||
    GosuListMode.updatedRange => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _workflowFilter = switch (widget.mode) {
      GosuListMode.activeFollowUp => GosuWorkflowFilter.inProgress,
      GosuListMode.awaitingFollowUp ||
      GosuListMode.all => GosuWorkflowFilter.all,
      _ when _hasWorkflowFilters => GosuWorkflowFilter.received,
      _ => GosuWorkflowFilter.all,
    };
    _listController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_listController.hasClients) return;
    final pos = _listController.position;
    if (pos.pixels > pos.maxScrollExtent - 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });
    try {
      final page = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchCallsPage(
            mode: widget.mode,
            fromYmd: widget.fromYmd,
            toYmdInclusive: widget.toYmdInclusive,
          );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _offset = page.items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(gosuSalesCallsRepositoryProvider)
          .fetchCallsPage(
            mode: widget.mode,
            fromYmd: widget.fromYmd,
            toYmdInclusive: widget.toYmdInclusive,
            offset: _offset,
          );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.items];
        _hasMore = page.hasMore;
        _offset += page.items.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  String get _title {
    if (widget.title != null) return widget.title!;
    return switch (widget.mode) {
      GosuListMode.todayReception || GosuListMode.dateRange => '자동문의고수 접수',
      GosuListMode.todayUpdated || GosuListMode.updatedRange => '금일 업데이트',
      GosuListMode.awaitingFollowUp => '팔로업중',
      GosuListMode.activeFollowUp => '기존진행중',
      GosuListMode.closed => '종료',
      GosuListMode.scheduled || GosuListMode.followRange => '팔로업 예정',
      GosuListMode.all => '전체',
    };
  }

  List<GosuSalesCall> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return _items.where((row) {
      final hay =
          '${row.displayName} ${row.displayPhone} ${row.inquiryContent ?? ''} ${row.displayRegion} ${row.assignedTo ?? ''} ${row.productCategoryName ?? ''}'
              .toLowerCase();
      if (hay.contains(q)) return true;
      if (digits.length >= 4 &&
          row.displayPhone.replaceAll(RegExp(r'\D'), '').contains(digits)) {
        return true;
      }
      return false;
    }).toList();
  }

  List<GosuSalesCall> get _receivedRows =>
      _filtered.where(isGosuAwaitingFirstFollowUp).toList();
  List<GosuSalesCall> get _activeRows =>
      _filtered.where(isGosuActiveFollowUp).toList();
  List<GosuSalesCall> get _closedRows => _filtered.where(isGosuClosed).toList();
  List<GosuSalesCall> get _openFollowRows =>
      _filtered.where(isGosuFollowUpOpen).toList();

  List<GosuSalesCall> get _shownRows => switch (_workflowFilter) {
    GosuWorkflowFilter.all => _filtered,
    GosuWorkflowFilter.received => _receivedRows,
    GosuWorkflowFilter.inProgress => _activeRows,
    GosuWorkflowFilter.closed => _closedRows,
    GosuWorkflowFilter.openFollow => _openFollowRows,
  };

  bool get _splitView =>
      _hasWorkflowFilters && _workflowFilter == GosuWorkflowFilter.all;

  Future<void> _openDetail(GosuSalesCall row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GosuCallDetailScreen(id: row.id, initial: row),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: kGosuCallCreateRouteName),
        builder: (_) => const GosuCallCreateScreen(),
      ),
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final rows = _shownRows;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_ic_call_rounded),
        label: const Text('새 접수'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '고객명, 전화, 문의내용',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_hasWorkflowFilters) _buildWorkflowFilters(scheme),
          Expanded(
            child: _loading
                ? const AppLoading(message: '자동문의고수 목록을 불러오는 중…')
                : _error != null
                ? AppErrorState(
                    message: koreanErrorMessage(_error!),
                    onRetry: _reload,
                  )
                : _filtered.isEmpty
                ? AppEmpty(
                    icon: Icons.phone_disabled_outlined,
                    message: _items.isEmpty
                        ? '등록된 자동문의고수 접수 건이 없습니다.'
                        : '검색 결과가 없습니다.',
                  )
                : rows.isEmpty && !_splitView
                ? AppEmpty(
                    icon: Icons.filter_alt_off_outlined,
                    message: '해당 상태 건이 없습니다.',
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: _splitView
                        ? _buildSplitList()
                        : _buildFlatList(rows),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowFilters(ColorScheme scheme) {
    final chips = <(GosuWorkflowFilter, String, int, Color)>[
      (GosuWorkflowFilter.all, '전체', _filtered.length, scheme.primary),
    ];
    if (_isAllCatalog) {
      chips.add((
        GosuWorkflowFilter.openFollow,
        '팔로업중',
        _openFollowRows.length,
        const Color(0xFF7C3AED),
      ));
      chips.add((
        GosuWorkflowFilter.closed,
        '종료',
        _closedRows.length,
        scheme.onSurfaceVariant,
      ));
    } else {
      chips.add((
        GosuWorkflowFilter.received,
        '접수',
        _receivedRows.length,
        const Color(0xFF0284C7),
      ));
      if (_showInProgressFilter) {
        chips.add((
          GosuWorkflowFilter.inProgress,
          '진행중',
          _activeRows.length,
          const Color(0xFFD97706),
        ));
      }
      if (_showClosedFilter) {
        chips.add((
          GosuWorkflowFilter.closed,
          '종료',
          _closedRows.length,
          scheme.onSurfaceVariant,
        ));
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final chip in chips) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${chip.$2} ${chip.$3}'),
                selected: _workflowFilter == chip.$1,
                showCheckmark: false,
                selectedColor: chip.$4,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: _workflowFilter == chip.$1
                      ? Colors.white
                      : scheme.onSurface,
                ),
                onSelected: (_) => setState(() => _workflowFilter = chip.$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlatList(List<GosuSalesCall> rows) {
    return ListView.separated(
      controller: _listController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: rows.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _GosuCallTile(
          row: rows[index],
          query: _query,
          onTap: () => _openDetail(rows[index]),
        );
      },
    );
  }

  Widget _buildSplitList() {
    final sections = <(String, Color, List<GosuSalesCall>)>[
      if (_isAllCatalog) ...[
        ('팔로업중', const Color(0xFF7C3AED), _openFollowRows),
        ('종료', const Color(0xFF475569), _closedRows),
      ] else ...[
        ('접수', const Color(0xFF0369A1), _receivedRows),
        ('진행중', const Color(0xFFB45309), _activeRows),
        if (_showClosedFilter) ('종료', const Color(0xFF475569), _closedRows),
      ],
    ];
    return ListView(
      controller: _listController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
      children: [
        for (final section in sections) ...[
          Container(
            width: double.infinity,
            color: section.$2.withValues(alpha: 0.12),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              '${section.$1} ${section.$3.length}',
              style: TextStyle(fontWeight: FontWeight.w900, color: section.$2),
            ),
          ),
          if (section.$3.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Text(
                '${section.$1} 건이 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  for (var i = 0; i < section.$3.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _GosuCallTile(
                      row: section.$3[i],
                      query: _query,
                      onTap: () => _openDetail(section.$3[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _GosuCallTile extends StatelessWidget {
  const _GosuCallTile({
    required this.row,
    required this.query,
    required this.onTap,
  });

  final GosuSalesCall row;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = gosuWorkflowStatusLabel(row);
    final statusColor = switch (status) {
      kGosuProgressClosed => scheme.onSurfaceVariant,
      kGosuStatusReceived => const Color(0xFF0369A1),
      _ => const Color(0xFFB45309),
    };
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: () {
          final phone = row.displayPhone;
          if (phone.isNotEmpty) LauncherUtils.makePhoneCall(phone);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchHighlightText(
                      text: row.displayName,
                      query: query,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SearchHighlightText(
                text: row.displayPhone.isEmpty ? '-' : row.displayPhone,
                query: query,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  row.displayRegion,
                  if ((row.productCategoryName ?? '').trim().isNotEmpty)
                    row.productCategoryName!.trim(),
                  if ((row.assignedTo ?? '').trim().isNotEmpty)
                    row.assignedTo!.trim(),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              if ((row.inquiryContent ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                SearchHighlightText(
                  text: row.inquiryContent!.trim(),
                  query: query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
