import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_search_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_completion_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_site_index.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerSupportSiteSearchScreen extends ConsumerStatefulWidget {
  const CustomerSupportSiteSearchScreen({super.key, this.title = '현장검색'});

  final String title;

  @override
  ConsumerState<CustomerSupportSiteSearchScreen> createState() =>
      _CustomerSupportSiteSearchScreenState();
}

class _CustomerSupportSiteSearchScreenState
    extends ConsumerState<CustomerSupportSiteSearchScreen> {
  final _queryCtrl = TextEditingController();
  String _query = '';
  String _branchTab = '전체';
  String _statusTab = '전체';
  List<SupportIndexedSite> _sites = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await ref
          .read(supportCallLogRepositoryProvider)
          .list(limit: 1000);
      var quotes = <SupportQuoteDocument>[];
      try {
        quotes = await ref.read(supportAsQuoteRepositoryProvider).list();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _sites = buildSupportIndexedSites(logs: logs, quotes: quotes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<Region> get _regions =>
      ref.watch(regionsRawProvider).valueOrNull ?? const [];

  List<SupportIndexedSite> get _branchSource {
    if (_branchTab == '전체') return _sites;
    return _sites
        .where((s) => supportIndexedSiteBranch(s, _regions) == _branchTab)
        .toList(growable: false);
  }

  List<SupportIndexedSite> get _filtered {
    var source = _branchSource;
    if (_statusTab != '전체') {
      source = source
          .where((s) => supportIndexedSiteMatchesStatus(s, _statusTab))
          .toList(growable: false);
    }
    return source
        .where((s) => supportIndexedSiteMatches(s, _query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => unawaited(_reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SupportBranchFilterBar(
            selected: _branchTab,
            counts: supportIndexedSiteBranchCounts(_sites, _regions),
            onSelected: (tab) => setState(() => _branchTab = tab),
          ),
          SupportStatusFilterBar(
            selected: _statusTab,
            counts: supportIndexedSiteStatusCounts(_branchSource),
            onSelected: (tab) => setState(() => _statusTab = tab),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '현장 · 주소 · 전화 · 담당자 · 견적',
              leading: const Icon(Icons.search_rounded, size: 20),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ],
              onChanged: (v) => setState(() => _query = v),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loading
                    ? '현장을 불러오는 중…'
                    : [
                        if (_branchTab != '전체') _branchTab,
                        if (_statusTab != '전체') _statusTab,
                        '${items.length}곳',
                        if (_query.trim().isEmpty &&
                            _branchTab == '전체' &&
                            _statusTab == '전체')
                          '완료 포함',
                      ].join(' · '),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoading(message: '전체 현장을 불러오는 중…')
                : _error != null
                ? AppEmpty(
                    icon: Icons.cloud_off_outlined,
                    message: '현장을 불러오지 못했습니다.',
                    detail: koreanErrorMessage(_error!),
                    actionLabel: '다시 시도',
                    onAction: () => unawaited(_reload()),
                  )
                : items.isEmpty
                ? const AppEmpty(
                    icon: Icons.location_off_outlined,
                    message: '검색 결과가 없습니다.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final site = items[i];
                      return _IndexedSiteTile(
                        site: site,
                        query: _query,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerSupportSiteDetailScreen(
                                site: site.toSiteSample(),
                                receptions: site.logs,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _IndexedSiteTile extends StatelessWidget {
  const _IndexedSiteTile({
    required this.site,
    required this.query,
    required this.onTap,
  });

  final SupportIndexedSite site;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchHighlightText(
                      text: site.title,
                      query: query,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      site.statusLabel.isEmpty
                          ? '접수 ${site.receptionCount}건'
                          : '${site.statusLabel} · ${site.receptionCount}건',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (site.address.trim().isNotEmpty)
                SearchHighlightText(
                  text: site.address,
                  query: query,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              SearchHighlightText(
                text: [
                  if (site.assignee.trim().isNotEmpty) site.assignee,
                  if (site.phone.trim().isNotEmpty) site.phone,
                  if (site.quotes.isNotEmpty) '견적 ${site.quotes.length}건',
                ].join(' · '),
                query: query,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerSupportSiteDetailScreen extends ConsumerStatefulWidget {
  const CustomerSupportSiteDetailScreen({
    super.key,
    required this.site,
    this.receptions = const [],
  });

  final SupportSiteSample site;
  final List<SupportCallLog> receptions;

  @override
  ConsumerState<CustomerSupportSiteDetailScreen> createState() =>
      _CustomerSupportSiteDetailScreenState();
}

class _CustomerSupportSiteDetailScreenState
    extends ConsumerState<CustomerSupportSiteDetailScreen> {
  List<SupportQuoteDocument> _quotes = const [];

  SupportSiteSample get site => widget.site;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadQuotes();
    });
  }

  Future<void> _loadQuotes() async {
    try {
      final rows = await ref
          .read(supportAsQuoteRepositoryProvider)
          .listForSite(
            phone: site.phone,
            site: site.name,
            customerName: site.name,
          );
      if (!mounted) return;
      setState(() => _quotes = rows);
    } catch (_) {}
  }

  List<SupportCallLog> get _receptions => widget.receptions;

  List<String> get _historyLines => [
    ...site.history,
    ..._quotes.map(supportQuoteHistoryLine),
  ];

  List<String> get _quoteLines {
    if (_quotes.isNotEmpty) {
      return _quotes.map(supportQuoteHistoryLine).toList();
    }
    return site.quotes;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(site.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _SiteHeader(site: site),
          const SizedBox(height: 12),
          SupportSectionCard(
            title: 'A. 재방문율',
            subtitle: '동일 현장 A/S ${site.revisitCount}회',
            icon: Icons.replay_circle_filled_outlined,
            badge: '${site.revisitCount}회',
            onTap: () => showSupportSkeletonSnack(context, '재방문 통계'),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'B. 히스토리',
            subtitle: _historyLines.isEmpty ? '이력 없음' : _historyLines.first,
            icon: Icons.history_rounded,
            badge: '${_historyLines.length}',
            onTap: () => _showHistory(context),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'C. 체크시트',
            subtitle: site.hasChecksheet
                ? '기존 체크시트 검색으로 이동'
                : '연결된 체크시트 없음 (검색은 가능)',
            icon: Icons.fact_check_outlined,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChecksheetSearchScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'D. 사업자등록증',
            subtitle: site.hasBusinessLicense ? '등록됨 · 미리보기 준비중' : '미등록',
            icon: Icons.badge_outlined,
            onTap: () => showSupportSkeletonSnack(context, '사업자등록증'),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'E. 주소',
            subtitle: site.addresses.join(' · '),
            icon: Icons.place_outlined,
            badge: '${site.addresses.length}곳',
            onTap: () => _showLines(context, '주소', site.addresses),
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'F. 기존 견적서',
            subtitle: _quoteLines.isEmpty
                ? '보낸 견적 없음 · 견적 화면으로 이동'
                : _quoteLines.first,
            icon: Icons.request_quote_outlined,
            badge: _quoteLines.isEmpty ? null : '${_quoteLines.length}',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupportQuoteWriterScreen(site: site),
                ),
              );
              if (mounted) await _loadQuotes();
            },
          ),
          const SizedBox(height: 8),
          SupportSectionCard(
            title: 'G. 설치완료일',
            subtitle: site.installCompletedYmd ?? '아직 설치 완료 기록이 없습니다',
            icon: Icons.event_available_outlined,
            onTap: () => showSupportSkeletonSnack(context, '설치완료일'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => openSupportIntakeThenDetail(context, site: site),
            icon: const Icon(Icons.add_ic_call_rounded),
            label: const Text('이 현장 AS 접수'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SupportQuoteWriterScreen(site: site, startNew: true),
              ),
            ),
            icon: const Icon(Icons.edit_document),
            label: const Text('견적서 작성'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CustomerSupportCompletionScreen(site: site),
              ),
            ),
            child: Text('완료확인서로', style: TextStyle(color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    final logs = _receptions;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const Text(
                'A/S 히스토리',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              if (logs.isNotEmpty) ...[
                for (final log in logs)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(
                      supportCallLogProgressLabel(log.serviceStatusId),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        log.customerName,
                        if ((log.createdAt ?? log.callDate) != null)
                          ymdSeoulFromDateTime(log.createdAt ?? log.callDate!),
                        if (log.issue.trim().isNotEmpty)
                          log.issue.trim().replaceAll('\n', ' '),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CustomerSupportReceptionDetailScreen(log: log),
                        ),
                      );
                    },
                  ),
              ],
              if (_quotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  '견적서',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final q in _quotes)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.request_quote_outlined, size: 18),
                    title: Text(supportQuoteHistoryLine(q)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final action = await showSupportQuoteExportSheet(
                        context,
                        doc: q,
                      );
                      if (!context.mounted) return;
                      if (action == SupportQuoteViewAction.edit) {
                        await pushSupportQuoteEditor(
                          context,
                          existing: q,
                          site: site,
                        );
                      }
                    },
                  ),
              ],
              if (logs.isEmpty && _quotes.isEmpty && _historyLines.isNotEmpty)
                for (final line in _historyLines)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(line),
                  ),
              if (logs.isEmpty && _quotes.isEmpty && _historyLines.isEmpty)
                const Text('이력이 없습니다.'),
            ],
          ),
        );
      },
    );
  }

  void _showLines(BuildContext context, String title, List<String> lines) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in lines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(line),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.site});

  final SupportSiteSample site;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            site.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${site.address}\n${site.assignee} · ${site.phone}',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
