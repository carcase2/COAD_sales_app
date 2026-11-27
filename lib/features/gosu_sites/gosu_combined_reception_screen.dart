import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/gosu_sales_calls_repository.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_detail_screen.dart';
import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_bucket_chips.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_detail_screen.dart';
import 'package:coad_customer_calls/features/gosu_sites/gosu_site_list_screen.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 금일 접수 — 전화 접수(gosu_sales_calls) + 홈페이지 문의(gosu_sites) 를 한 목록으로.
class GosuCombinedReceptionScreen extends ConsumerStatefulWidget {
  const GosuCombinedReceptionScreen({
    super.key,
    required this.title,
    required this.fromYmd,
    required this.toYmdInclusive,
  });

  final String title;
  final String fromYmd;
  final String toYmdInclusive;

  @override
  ConsumerState<GosuCombinedReceptionScreen> createState() =>
      _GosuCombinedReceptionScreenState();
}

enum _Source { all, phone, homepage }

class _Entry {
  _Entry.phone(GosuSalesCall c)
    : phone = c,
      site = null,
      bucket = isGosuClosed(c)
          ? GosuSiteBucket.canceled
          : isGosuAwaitingFirstFollowUp(c)
          ? GosuSiteBucket.receiving
          : GosuSiteBucket.accepted,
      sortKey = '${c.callDate ?? ''} ${c.callTime ?? ''}';
  _Entry.site(GosuSite s)
    : phone = null,
      site = s,
      bucket = gosuSiteBucket(s),
      sortKey = formatSeoulDateTime(s.receivedAt);

  /// 전화: 1차 팔로업 전 = 접수중, 진행중 = 접수완료, 종료 = 취소·종료.
  final GosuSiteBucket bucket;

  final GosuSalesCall? phone;
  final GosuSite? site;

  /// `yyyy-MM-dd HH:mm` (한국 시간) — 최신이 위로.
  final String sortKey;
}

class _GosuCombinedReceptionScreenState
    extends ConsumerState<GosuCombinedReceptionScreen> {
  List<GosuSalesCall> _phone = [];
  List<GosuSite> _sites = [];
  bool _loading = true;
  bool _syncing = false;
  Object? _error;
  _Source _source = _Source.all;
  GosuSiteBucket? _bucket;

  @override
  void initState() {
    super.initState();
    _load();
    _autoSync();
  }

  Future<void> _autoSync() async {
    final repo = ref.read(gosuSitesRepositoryProvider);
    if (!repo.canSync) return;
    setState(() => _syncing = true);
    final synced = await repo.syncIfStale();
    if (!mounted) return;
    setState(() => _syncing = false);
    if (synced) _load(silent: true);
  }

  Future<void> _syncNow() async {
    final repo = ref.read(gosuSitesRepositoryProvider);
    setState(() => _syncing = true);
    final r = await repo.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.ok ? '고수 사이트에서 새로 가져왔습니다.' : r.error ?? '동기화 실패'),
      ),
    );
    if (r.ok) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        ref
            .read(gosuSalesCallsRepositoryProvider)
            .fetchCallsPage(
              mode: GosuListMode.dateRange,
              fromYmd: widget.fromYmd,
              toYmdInclusive: widget.toYmdInclusive,
              limit: 1000,
            ),
        ref
            .read(gosuSitesRepositoryProvider)
            .fetchReceivedBetween(widget.fromYmd, widget.toYmdInclusive),
      ]);
      if (!mounted) return;
      setState(() {
        _phone = (results[0] as GosuListPage).items;
        _sites = results[1] as List<GosuSite>;
        _loading = false;
        _error = null;
      });
      ref.invalidate(gosuSiteCountsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// 출처 필터만 적용한 전체 (상태 칩 건수용).
  List<_Entry> get _sourced => [
    if (_source != _Source.homepage) ..._phone.map(_Entry.phone),
    if (_source != _Source.phone) ..._sites.map(_Entry.site),
  ];

  /// 접수중 → 접수완료 → 취소·종료, 같은 묶음은 최근 접수가 위.
  List<_Entry> get _entries {
    final list = _sourced
        .where((e) => _bucket == null || e.bucket == _bucket)
        .toList();
    list.sort((a, b) {
      final c = a.bucket.index.compareTo(b.bucket.index);
      return c != 0 ? c : b.sortKey.compareTo(a.sortKey);
    });
    return list;
  }

  String _bucketLabel(GosuSiteBucket b) =>
      b == GosuSiteBucket.canceled && _source != _Source.homepage
      ? '취소·종료'
      : gosuSiteBucketLabel(b);

  Future<void> _open(_Entry e) async {
    final nav = Navigator.of(context);
    if (e.phone != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              GosuCallDetailScreen(id: e.phone!.id, initial: e.phone),
        ),
      );
    } else {
      await nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => GosuSiteDetailScreen(initial: e.site!),
        ),
      );
    }
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.gosuAccent(scheme);
    final entries = _entries;
    final range = widget.fromYmd == widget.toYmdInclusive
        ? widget.fromYmd
        : '${widget.fromYmd} ~ ${widget.toYmdInclusive}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '고수에서 새로고침',
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoading(message: '접수를 불러오는 중…')
          : _error != null
          ? AppErrorState(message: koreanErrorMessage(_error!), onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                children: [
                  Text(
                    '$range · 전화 ${_phone.length} · 홈페이지 ${_sites.length}'
                    '${_sites.isEmpty ? '' : ' (${GosuSiteBucket.values.map((b) => '${gosuSiteBucketLabel(b)} ${_sites.where((x) => gosuSiteBucket(x) == b).length}').join(' · ')})'}'
                    '${_syncing ? ' · 고수에서 가져오는 중…' : ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (s, label) in [
                        (_Source.all, '전체 ${_phone.length + _sites.length}'),
                        (_Source.phone, '전화 ${_phone.length}'),
                        (_Source.homepage, '홈페이지 ${_sites.length}'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _source == s,
                          onSelected: (_) => setState(() => _source = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GosuSiteBucketChips(
                    counts: gosuBucketCounts(_sourced.map((e) => e.bucket)),
                    selected: _bucket,
                    labelOf: _bucketLabel,
                    onSelected: (b) => setState(() => _bucket = b),
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: AppEmpty(message: '접수가 없습니다.'),
                    ),
                  for (final (i, e) in entries.indexed) ...[
                    if (i == 0 || entries[i - 1].bucket != e.bucket)
                      GosuBucketHeader(
                        bucket: e.bucket,
                        count: entries
                            .where((x) => x.bucket == e.bucket)
                            .length,
                        labelOf: _bucketLabel,
                      ),
                    if (e.site != null)
                      GosuSiteCard(
                        site: e.site!,
                        showSource: true,
                        onTap: () => _open(e),
                      )
                    else
                      _PhoneCard(call: e.phone!, onTap: () => _open(e)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.call, required this.onTap});

  final GosuSalesCall call;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = gosuWorkflowStatusLabel(call);
    final content = (call.inquiryContent ?? '').replaceAll(RegExp(r'\s+'), ' ');
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      call.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '전화 · $status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '접수 ${call.callDate ?? ''} ${call.callTime ?? ''} · 담당 ${call.assignedTo ?? '-'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                '${call.displayPhone.isEmpty ? '-' : call.displayPhone} · ${call.displayRegion}',
                style: const TextStyle(fontSize: 13),
              ),
              if (content.isNotEmpty)
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
