import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_detail.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 발급완료 전용 화면 — 오늘 완료 건 강조, 담당자 칩으로 바로 필터.
class IssuanceCompletedListPage extends ConsumerStatefulWidget {
  const IssuanceCompletedListPage({required this.domain, super.key});

  final IssuanceDomain domain;

  @override
  ConsumerState<IssuanceCompletedListPage> createState() =>
      _IssuanceCompletedListPageState();
}

enum _CompletedDateFilter { today, week, month, all }

enum _MesFilter { all, yes, no }

class _IssuanceCompletedListPageState
    extends ConsumerState<IssuanceCompletedListPage> {
  late IssuanceDomain _domain;
  bool _olderExpanded = false;
  _CompletedDateFilter _dateFilter = _CompletedDateFilter.all;
  _MesFilter _mesFilter = _MesFilter.all;

  void _syncOlderExpanded({
    required bool todayEmpty,
    required bool olderNotEmpty,
  }) {
    if (todayEmpty && olderNotEmpty && !_olderExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _olderExpanded = true);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _domain = widget.domain;
  }

  bool get _isTax => _domain == IssuanceDomain.taxInvoice;

  Color get _accent =>
      _isTax ? Colors.indigo.shade600 : Colors.deepOrange.shade700;

  String get _domainLabel => _isTax ? '세금계산서' : '이행증권';

  String get _todayLabel {
    final ymd = todayYmdSeoul();
    final parts = ymd.split('-');
    if (parts.length != 3) return '오늘';
    return '오늘 ${parts[1]}/${parts[2]}';
  }

  Future<void> _refresh() async {
    ref.invalidate(issuanceAllRowsProvider(_domain));
    ref.invalidate(issuanceRequestBadgeCountProvider);
    ref.invalidate(issuanceRequestTotalBadgeCountProvider);
    await ref.read(issuanceAllRowsProvider(_domain).future);
  }

  String _issueYmd(IssuanceRequestRow row) {
    for (final raw in [row.issue?['issue_date'], row.master['issue_date']]) {
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.length >= 10) return s.substring(0, 10);
    }
    return ymdSeoulFromDateTime(row.createdAt);
  }

  bool _isTodayRow(IssuanceRequestRow row) => _issueYmd(row) == todayYmdSeoul();

  bool _matchesDateFilter(IssuanceRequestRow row) {
    final ymd = _issueYmd(row);
    final today = todayYmdSeoul();
    switch (_dateFilter) {
      case _CompletedDateFilter.today:
        return ymd == today;
      case _CompletedDateFilter.week:
        final range = seoulWeekRangeContaining(today);
        return ymd.compareTo(range.$1) >= 0 && ymd.compareTo(range.$2) <= 0;
      case _CompletedDateFilter.month:
        return ymd.startsWith(today.substring(0, 7));
      case _CompletedDateFilter.all:
        return true;
    }
  }

  bool _matchesMesFilter(IssuanceRequestRow row) {
    if (!_isTax || _mesFilter == _MesFilter.all) return true;
    final mes = row.master['mes_registered'] == true;
    return _mesFilter == _MesFilter.yes ? mes : !mes;
  }

  List<IssuanceRequestRow> _applyListFilters(List<IssuanceRequestRow> rows) {
    return rows.where(_matchesDateFilter).where(_matchesMesFilter).toList();
  }

  void _switchDomain(IssuanceDomain domain) {
    if (_domain == domain) return;
    setState(() {
      _domain = domain;
      _olderExpanded = false;
      if (domain != IssuanceDomain.taxInvoice) {
        _mesFilter = _MesFilter.all;
      }
    });
  }

  Widget _buildListFilters(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '발행일',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip(
                scheme: scheme,
                label: '금일',
                selected: _dateFilter == _CompletedDateFilter.today,
                onTap: () =>
                    setState(() => _dateFilter = _CompletedDateFilter.today),
              ),
              _filterChip(
                scheme: scheme,
                label: '금주',
                selected: _dateFilter == _CompletedDateFilter.week,
                onTap: () =>
                    setState(() => _dateFilter = _CompletedDateFilter.week),
              ),
              _filterChip(
                scheme: scheme,
                label: '금월',
                selected: _dateFilter == _CompletedDateFilter.month,
                onTap: () =>
                    setState(() => _dateFilter = _CompletedDateFilter.month),
              ),
              _filterChip(
                scheme: scheme,
                label: '전체',
                selected: _dateFilter == _CompletedDateFilter.all,
                onTap: () =>
                    setState(() => _dateFilter = _CompletedDateFilter.all),
              ),
            ],
          ),
          if (_isTax) ...[
            const SizedBox(height: 10),
            Text(
              'MES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _filterChip(
                  scheme: scheme,
                  label: '전체',
                  selected: _mesFilter == _MesFilter.all,
                  onTap: () => setState(() => _mesFilter = _MesFilter.all),
                ),
                _filterChip(
                  scheme: scheme,
                  label: '등록',
                  selected: _mesFilter == _MesFilter.yes,
                  onTap: () => setState(() => _mesFilter = _MesFilter.yes),
                ),
                _filterChip(
                  scheme: scheme,
                  label: '미등록',
                  selected: _mesFilter == _MesFilter.no,
                  onTap: () => setState(() => _mesFilter = _MesFilter.no),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip({
    required ColorScheme scheme,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: _accent.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: selected ? _accent : scheme.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }

  Widget _buildDomainSwitcher(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: _DomainTab(
                label: '세금계산서',
                selected: _isTax,
                accent: Colors.indigo.shade600,
                onTap: () => _switchDomain(IssuanceDomain.taxInvoice),
              ),
            ),
            Expanded(
              child: _DomainTab(
                label: '이행증권',
                selected: !_isTax,
                accent: Colors.deepOrange.shade700,
                onTap: () => _switchDomain(IssuanceDomain.performanceBond),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary({
    required ColorScheme scheme,
    required int todayCount,
    required int totalCount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accent, _accent.withValues(alpha: 0.82)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _todayLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_domainLabel 발급완료',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$todayCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  Text(
                    '금일 · 전체 $totalCount건',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required int count,
    required ColorScheme scheme,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          if (highlight)
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: highlight ? _accent : scheme.onSurface,
              ),
            ),
          ),
          Text(
            '$count건',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList(List<IssuanceRequestRow> rows) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _IssuanceCompletedCard(
              row: rows[i],
              accent: _accent,
              isTax: _isTax,
              showAssignee: true,
              onTap: () => showIssuanceRequestDetail(context, rows[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHint(String message, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completedAsync = ref.watch(issuanceCompletedRowsProvider(_domain));

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('발급완료'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: completedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('발급완료 목록을 불러오지 못했습니다.\n$e'),
          ),
        ),
        data: (allCompleted) {
          final user = ref.watch(authControllerProvider);
          final filtered = sortIssuanceRowsOwnFirst(
            _applyListFilters(allCompleted),
            user?.name,
          );
          final todayRows = filtered.where(_isTodayRow).toList();
          final olderRows = filtered.where((r) => !_isTodayRow(r)).toList();
          _syncOlderExpanded(
            todayEmpty: todayRows.isEmpty,
            olderNotEmpty: olderRows.isNotEmpty,
          );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildDomainSwitcher(scheme)),
                SliverToBoxAdapter(child: _buildListFilters(scheme)),
                SliverToBoxAdapter(
                  child: _buildTodaySummary(
                    scheme: scheme,
                    todayCount: todayRows.length,
                    totalCount: filtered.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSectionTitle(
                    title: '금일 발급완료',
                    count: todayRows.length,
                    scheme: scheme,
                    highlight: true,
                  ),
                ),
                if (todayRows.isEmpty)
                  SliverToBoxAdapter(
                    child: _buildEmptyHint(
                      '오늘 발급 완료된 $_domainLabel 건이 없습니다.',
                      scheme,
                    ),
                  )
                else
                  SliverToBoxAdapter(child: _buildCardList(todayRows)),
                SliverToBoxAdapter(
                  child: InkWell(
                    onTap: () =>
                        setState(() => _olderExpanded = !_olderExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '이전 발급완료',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '${olderRows.length}건',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            _olderExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_olderExpanded) ...[
                  if (olderRows.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyHint('이전 발급완료 건이 없습니다.', scheme),
                    )
                  else
                    SliverToBoxAdapter(child: _buildCardList(olderRows)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DomainTab extends StatelessWidget {
  const _DomainTab({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _IssuanceCompletedCard extends StatelessWidget {
  const _IssuanceCompletedCard({
    required this.row,
    required this.accent,
    required this.isTax,
    required this.showAssignee,
    required this.onTap,
  });

  final IssuanceRequestRow row;
  final Color accent;
  final bool isTax;
  final bool showAssignee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final master = row.master;
    String textOf(String key) => (master[key] ?? '').toString().trim();

    final title = isTax
        ? (textOf('customer_name').isEmpty
              ? row.title
              : textOf('customer_name'))
        : (textOf('company_name').isEmpty ? row.title : textOf('company_name'));
    final assignee = textOf('requester').isEmpty
        ? textOf('created_by')
        : textOf('requester');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '발급완료',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    row.createdAtText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  height: 1.25,
                ),
              ),
              if (showAssignee) ...[
                const SizedBox(height: 4),
                Text(
                  '담당: ${assignee.isEmpty ? '미지정' : assignee}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                isTax
                    ? '품목: ${textOf('item_name').isEmpty ? '-' : textOf('item_name')}'
                    : '종류: ${textOf('bond_type').isEmpty ? '-' : textOf('bond_type')}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
