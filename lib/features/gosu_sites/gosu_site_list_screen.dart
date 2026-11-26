import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_detail_screen.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_visit_calendar_screen.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GosuSiteTab { today, receiving, cancel }

/// 고수 사이트 홈페이지 문의 목록. 오늘 접수 · 접수중 · 접수취소.
class GosuSiteListScreen extends ConsumerStatefulWidget {
  const GosuSiteListScreen({
    super.key,
    this.initialTab = GosuSiteTab.receiving,
  });

  final GosuSiteTab initialTab;

  @override
  ConsumerState<GosuSiteListScreen> createState() => _GosuSiteListScreenState();
}

class _GosuSiteListScreenState extends ConsumerState<GosuSiteListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  final Map<GosuSiteTab, List<GosuSite>> _rows = {};
  Set<String> _cancelWithReason = {};
  DateTime? _lastSync;
  bool _loading = true;
  Object? _error;
  bool _staleOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(gosuSitesRepositoryProvider);
    try {
      final results = await Future.wait([
        repo.fetchReceivedOn(todayYmdSeoul()),
        repo.fetchReceiving(),
        repo.fetchCanceled(),
      ]);
      final withReason = await repo.fetchCancelReasonIds(
        results[2].map((s) => s.gosuId),
      );
      final lastSync = await repo.fetchLastSyncAt();
      if (!mounted) return;
      setState(() {
        _rows[GosuSiteTab.today] = results[0];
        _rows[GosuSiteTab.receiving] = results[1];
        _rows[GosuSiteTab.cancel] = results[2];
        _cancelWithReason = withReason;
        _lastSync = lastSync;
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

  bool _needsCancelReason(GosuSite s) =>
      !_cancelWithReason.contains(s.gosuId) && s.gosuMemo == null;

  List<GosuSite> _filtered(GosuSiteTab tab) {
    var list = _rows[tab] ?? const <GosuSite>[];
    if (tab == GosuSiteTab.receiving && _staleOnly) {
      list = list.where((s) => gosuSiteStaleReason(s) != null).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return list.where((s) {
      if (digits.length >= 3 &&
          (s.customerPhone ?? '')
              .replaceAll(RegExp(r'\D'), '')
              .contains(digits)) {
        return true;
      }
      return [
        s.customerName,
        s.address,
        s.productName,
        s.workerName,
        s.requestText,
      ].any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(GosuSite site) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GosuSiteDetailScreen(initial: site)),
    );
    if (changed == true) {
      ref.invalidate(gosuSiteCountsProvider);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final receiving = _rows[GosuSiteTab.receiving] ?? const [];
    final staleCount = receiving
        .where((s) => gosuSiteStaleReason(s) != null)
        .length;
    final cancelTodo = (_rows[GosuSiteTab.cancel] ?? const [])
        .where(_needsCancelReason)
        .length;

    String tabLabel(String name, int? n) => n == null ? name : '$name $n';

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈페이지 문의 (고수)'),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '방문 달력',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GosuSiteVisitCalendarScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: [
            Tab(text: tabLabel('오늘 접수', _rows[GosuSiteTab.today]?.length)),
            Tab(text: tabLabel('접수중', _rows[GosuSiteTab.receiving]?.length)),
            Tab(text: tabLabel('접수취소', _loading ? null : cancelTodo)),
          ],
        ),
      ),
      body: _loading
          ? const AppLoading(message: '홈페이지 문의를 불러오는 중…')
          : _error != null
          ? AppErrorState(message: koreanErrorMessage(_error!), onRetry: _load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: '이름 · 전화 · 주소 · 담당자',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    _lastSync == null
                        ? '고수 사이트에서 20분마다 가져옵니다.'
                        : '고수에서 가져온 시각 ${formatSeoulMonthDayTime(_lastSync)} · 20분마다 자동',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _list(GosuSiteTab.today, '오늘 들어온 홈페이지 문의가 없습니다.'),
                      Column(
                        children: [
                          if (staleCount > 0 || _staleOnly)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FilterChip(
                                  label: Text('지연만 보기 ($staleCount)'),
                                  selected: _staleOnly,
                                  selectedColor: scheme.errorContainer,
                                  onSelected: (v) =>
                                      setState(() => _staleOnly = v),
                                ),
                              ),
                            ),
                          Expanded(
                            child: _list(
                              GosuSiteTab.receiving,
                              '접수중인 홈페이지 문의가 없습니다.',
                            ),
                          ),
                        ],
                      ),
                      _list(GosuSiteTab.cancel, '최근 30일 접수취소가 없습니다.'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _list(GosuSiteTab tab, String empty) {
    final rows = _filtered(tab);
    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 60),
                AppEmpty(message: empty),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => GosuSiteCard(
                site: rows[i],
                needsCancelReason:
                    tab == GosuSiteTab.cancel && _needsCancelReason(rows[i]),
                onTap: () => _open(rows[i]),
              ),
            ),
    );
  }
}

class GosuSiteCard extends StatelessWidget {
  const GosuSiteCard({
    super.key,
    required this.site,
    required this.onTap,
    this.needsCancelReason = false,
  });

  final GosuSite site;
  final VoidCallback onTap;
  final bool needsCancelReason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stale = gosuSiteStaleReason(site);
    final call = site.lastResult == null
        ? null
        : parseGosuSiteCall(site.lastResult!);
    final canceled = site.workerStatus == kGosuSiteCanceled;
    final statusColor = canceled
        ? scheme.error
        : site.workerStatus == kGosuSiteReceiving
        ? AppTokens.gosuAccent(scheme)
        : scheme.tertiary;

    final lines = <String>[
      '${site.displayPhone} · ${gosuSiteRegion(site)}',
      site.productLabel,
      if (call != null)
        '${call.round}차 통화 · ${call.outcome}${site.lastNextActionAt != null && !canceled ? ' → 다음 ${formatSeoulDate(site.lastNextActionAt)}' : ''}'
      else if (!canceled)
        '통화 기록 없음',
      if (site.onsiteAt != null && !canceled)
        '방문 ${formatSeoulMonthDayTime(site.onsiteAt)}',
    ];

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: stale != null ? scheme.error : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      site.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _Chip(
                    text: gosuSiteStatusLabel(site.workerStatus),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '접수 ${formatSeoulMonthDayTime(site.receivedAt)} · 담당 ${site.workerName ?? '미배정'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              for (final l in lines)
                Text(
                  l,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              if (stale != null) ...[
                const SizedBox(height: 6),
                Text(
                  '⚠ $stale',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.error,
                  ),
                ),
              ],
              if (needsCancelReason) ...[
                const SizedBox(height: 6),
                Text(
                  '취소 사유 미기록',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
