import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_collection_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_schedule_calendar_screen.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/customer_support/support_first_consultation_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_date_picker.dart';
import 'package:coad_customer_calls/features/customer_support/support_sites_map_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_site_index.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/home/home_dept.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> openSupportIntakeThenDetail(
  BuildContext context,
  WidgetRef ref, {
  SupportSiteSample? site,
}) async {
  final created = await Navigator.of(context).push<SupportCallLog>(
    MaterialPageRoute(builder: (_) => CustomerSupportIntakeScreen(site: site)),
  );
  if (!context.mounted || created == null) return;
  invalidateSupportWorkCaches(ref);
  navigateToHomeAndRefresh(
    context,
    ref,
    deptPageIndex: kHomeDeptCustomerSupport,
    message: '접수가 저장되었습니다. 홈에서 1차 상담을 남겨 주세요.',
  );
}

class CustomerSupportReceptionListScreen extends ConsumerStatefulWidget {
  const CustomerSupportReceptionListScreen({
    super.key,
    this.title = 'A/S 접수내역',
    this.fromYmd,
    this.toYmdInclusive,
    this.pendingOnly = false,
    this.visitOnly = false,
    this.incompleteOnly = false,
    this.statusId,
    this.consultOutcome,
    this.quoteSentOnly = false,
    this.initialStatusTab,
    this.initialBranch,
  });

  final String title;
  final String? fromYmd;
  final String? toYmdInclusive;
  final bool pendingOnly;
  final bool visitOnly;
  final bool incompleteOnly;
  final int? statusId;
  final SupportConsultOutcome? consultOutcome;
  /// 정식 견적서 중 발송완료만 (발송 후 고객 답 대기).
  final bool quoteSentOnly;
  final String? initialStatusTab;
  final String? initialBranch;

  @override
  ConsumerState<CustomerSupportReceptionListScreen> createState() =>
      _CustomerSupportReceptionListScreenState();
}

class _CustomerSupportReceptionListScreenState
    extends ConsumerState<CustomerSupportReceptionListScreen> {
  final _queryCtrl = TextEditingController();
  List<SupportCallLog> _items = const [];
  Map<String, SupportConsultSnapshot> _lastConsults = const {};
  bool _loading = true;
  Object? _error;
  String _query = '';
  String _branchTab = '전체';
  late String _statusTab;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStatusTab;
    _statusTab =
        initial == '답 대기·견적서'
            ? '대기'
            : (initial ??
                  (widget.pendingOnly
                      ? '미처리'
                      : widget.statusId == kSupportStatusCompleted
                      ? '전체'
                      : widget.visitOnly
                      ? '방문예정'
                      : '전체'));
    final branch = (widget.initialBranch ?? '').trim();
    if (kSupportBranchTabOrder.contains(branch)) {
      _branchTab = branch;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<SupportCallLog> get _branchSource {
    if (_branchTab == '전체') return _items;
    return _items
        .where((e) => _branchOf(e) == _branchTab)
        .toList(growable: false);
  }

  List<SupportCallLog> get _filtered {
    final q = _query.trim().toLowerCase();
    var source = _branchSource;
    final statusFilterActive =
        !_waitOutcomeLocked &&
        !widget.pendingOnly &&
        !widget.visitOnly &&
        widget.statusId == null &&
        _statusTab != '전체';
    if (statusFilterActive) {
      source = source
          .where(
            (e) => supportCallLogProgressLabel(e.serviceStatusId) == _statusTab,
          )
          .toList(growable: false);
    }
    if (q.isEmpty) return source;
    return source
        .where((e) {
          final blob = [
            e.customerName,
            e.customerPhone,
            e.address ?? '',
            e.issue,
            e.createdBy ?? '',
          ].join(' ').toLowerCase();
          return blob.contains(q);
        })
        .toList(growable: false);
  }

  /// 고객 대기(피드백·구두·발송 후) — 홈 건수와 같은 스냅 기준.
  bool get _waitOutcomeLocked =>
      widget.consultOutcome != null || widget.quoteSentOnly;

  String get _waitFilterLabel {
    if (widget.quoteSentOnly) return '발송 후 대기';
    return switch (widget.consultOutcome) {
      SupportConsultOutcome.feedbackWait => '피드백 대기',
      SupportConsultOutcome.verbalQuote => '구두 견적',
      SupportConsultOutcome.quoteSend => '정식 견적서',
      _ => widget.title,
    };
  }

  Map<String, int> _statusCounts() {
    final source = _branchSource;
    final counts = <String, int>{'전체': source.length};
    for (final log in source) {
      final label = supportCallLogProgressLabel(log.serviceStatusId);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(supportCallLogRepositoryProvider);
      // 고객 대기 카드: 진행중 전체 → 상담·발송 enrich → 카드 조건으로 필터.
      final rows = _waitOutcomeLocked
          ? await repo.list(
              statusId: kSupportStatusInProgress,
              limit: 400,
            )
          : await repo.list(
              fromYmd: widget.fromYmd,
              toYmdInclusive: widget.toYmdInclusive,
              pendingOnly: widget.pendingOnly,
              visitOnly: widget.visitOnly,
              incompleteOnly: widget.incompleteOnly,
              statusId: widget.statusId,
              limit: widget.incompleteOnly ? 400 : 150,
            );
      Map<String, SupportConsultSnapshot> last = const {};
      try {
        last = await repo.lastConsultSnapshots(rows.map((e) => e.id));
      } catch (_) {}
      try {
        final raw = last;
        final sentByLog = await ref
            .read(supportAsQuoteRepositoryProvider)
            .sentYmdForCallLogs(
              rows.map(
                (e) => (
                  id: e.id,
                  phone: e.customerPhone,
                  customerName: e.customerName,
                ),
              ),
            );
        last = enrichConsultSnapshotsWithQuoteSent(raw, sentByLog);
        for (final e in sentByLog.entries) {
          final before = raw[e.key];
          final needsHeal =
              before == null ||
              before.outcome == SupportConsultOutcome.verbalQuote ||
              before.outcome == SupportConsultOutcome.feedbackWait ||
              (before.outcome == SupportConsultOutcome.quoteSend &&
                  (before.sentYmd ?? '').trim().isEmpty);
          if (!needsHeal) continue;
          unawaited(
            repo.markLatestQuoteSentForCallLog(e.key, sentYmd: e.value),
          );
        }
      } catch (_) {}
      var visible = rows;
      if (widget.quoteSentOnly) {
        visible = rows
            .where((e) {
              final s = last[e.id];
              return s?.outcome == SupportConsultOutcome.quoteSend &&
                  (s?.sentYmd ?? '').trim().isNotEmpty;
            })
            .toList();
      } else if (widget.consultOutcome != null) {
        visible = rows
            .where((e) => last[e.id]?.outcome == widget.consultOutcome)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _items = visible;
        _lastConsults = last;
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

  Future<void> _openCreate() async {
    await openSupportIntakeThenDetail(context, ref);
    if (mounted) unawaited(_reload());
  }

  String _when(SupportCallLog log) {
    return formatSeoulMonthDayTime(log.createdAt ?? log.callDate);
  }

  List<SupportCallLog> get _displayRows {
    final rows = _filtered;
    if (widget.fromYmd != null) {
      return rows.reversed.toList(growable: false);
    }
    return rows;
  }

  List<Region> get _regions =>
      ref.watch(regionsRawProvider).valueOrNull ?? const [];

  String _branchOf(SupportCallLog log) =>
      matchSupportBranchType(log.address ?? '', _regions);

  Map<String, int> _branchCounts() {
    final counts = <String, int>{'전체': _items.length};
    for (final log in _items) {
      final b = _branchOf(log);
      counts[b] = (counts[b] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final rows = _displayRows;
    final counts = _branchCounts();
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.title,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'A/S 단가표',
            onPressed: () => openSupportUnitPriceLookup(context),
            icon: const Icon(Icons.grid_on_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: (value) async {
              switch (value) {
                case 'map':
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SupportSitesMapScreen(
                        pendingOnly: widget.pendingOnly,
                        initialBranch: _branchTab,
                      ),
                    ),
                  );
                case 'calendar':
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const CustomerSupportScheduleCalendarScreen(),
                    ),
                  );
                  if (mounted) unawaited(_reload());
                case 'refresh':
                  if (!_loading) unawaited(_reload());
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'map', child: Text('현장 지도')),
              PopupMenuItem(value: 'calendar', child: Text('방문·발송 달력')),
              PopupMenuItem(value: 'refresh', child: Text('새로고침')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 접수'),
      ),
      body: Column(
        children: [
          SupportBranchFilterBar(
            selected: _branchTab,
            counts: counts,
            onSelected: (tab) => setState(() => _branchTab = tab),
          ),
          if (_waitOutcomeLocked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: AppTokens.customerSupportAccent(
                  scheme,
                ).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt_rounded,
                        size: 16,
                        color: AppTokens.customerSupportAccent(scheme),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '필터 · $_waitFilterLabel · ${_items.length}건',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTokens.customerSupportAccent(scheme),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_waitOutcomeLocked &&
              !widget.pendingOnly &&
              !widget.visitOnly &&
              widget.statusId == null)
            SupportStatusFilterBar(
              selected: _statusTab,
              counts: _statusCounts(),
              hideCompleted: widget.incompleteOnly,
              onSelected: (tab) => setState(() => _statusTab = tab),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SearchBar(
              controller: _queryCtrl,
              hintText: '이름 · 전화 · 주소 · 내용',
              leading: const Icon(Icons.search_rounded, size: 20),
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
          Expanded(
            child: _loading
                ? const AppLoading(message: '접수 내역을 불러오는 중…')
                : _error != null
                ? AppEmpty(
                    icon: Icons.cloud_off_outlined,
                    message: '내역을 불러오지 못했습니다.',
                    detail: koreanErrorMessage(_error!),
                    actionLabel: '다시 시도',
                    onAction: () => unawaited(_reload()),
                  )
                : rows.isEmpty
                ? AppEmpty(
                    icon: Icons.list_alt_outlined,
                    message: _query.trim().isEmpty
                        ? (widget.fromYmd == null
                              ? '저장된 접수가 없습니다.'
                              : '이 기간에 해당하는 접수가 없습니다.')
                        : '검색 결과가 없습니다.',
                    actionLabel: _query.trim().isEmpty ? '새 접수' : null,
                    onAction: _query.trim().isEmpty ? _openCreate : null,
                  )
                : RefreshIndicator(
                    onRefresh: _reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final log = rows[i];
                        final parsed = parseSupportIssueBody(log.issue);
                        final urgency = supportUrgencyColor(
                          scheme,
                          parsed.urgency,
                        );
                        final cue = supportFlowCueFromLog(
                          log,
                          last: _lastConsults[log.id],
                        );
                        return Material(
                          color: Color.lerp(scheme.surface, urgency, 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: urgency.withValues(alpha: 0.45),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              final changed = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute<bool>(
                                      builder: (_) =>
                                          CustomerSupportReceptionDetailScreen(
                                            log: log,
                                          ),
                                    ),
                                  );
                              if (changed == true && mounted) {
                                invalidateSupportWorkCaches(ref);
                                unawaited(_reload());
                              }
                            },
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 6, color: urgency),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: urgency,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          supportUrgencyLabel(parsed.urgency),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: urgency,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        0,
                                        10,
                                        8,
                                        10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  log.customerName.isEmpty
                                                      ? '(이름 없음)'
                                                      : log.customerName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _when(log),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (parsed.siteName.isNotEmpty ||
                                              parsed.productName.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                [
                                                  if (parsed
                                                      .productName
                                                      .isNotEmpty)
                                                    parsed.productName,
                                                  if (parsed
                                                      .siteName
                                                      .isNotEmpty)
                                                    parsed.siteName,
                                                ].join(' · '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: urgency,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 2),
                                          Text(
                                            [
                                              if (log.customerPhone
                                                  .trim()
                                                  .isNotEmpty)
                                                formatKoreanPhoneHyphenated(
                                                  log.customerPhone,
                                                ),
                                              if ((log.address ?? '')
                                                  .trim()
                                                  .isNotEmpty)
                                                log.address!.trim(),
                                            ].join(' · '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (parsed.body.trim().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Text(
                                                parsed.body.trim(),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _ListChip(
                                                label:
                                                    supportCallLogProgressLabel(
                                                      log.serviceStatusId,
                                                    ),
                                                color: switch (log
                                                    .serviceStatusId) {
                                                  _ when log.isPending =>
                                                    scheme.error,
                                                  kSupportStatusVisitScheduled =>
                                                    scheme.tertiary,
                                                  kSupportStatusCompleted =>
                                                    AppTokens.success(scheme),
                                                  _ => scheme.primary,
                                                },
                                              ),
                                              if ((log.visitDate ?? '')
                                                      .isNotEmpty &&
                                                  log.serviceStatusId !=
                                                      kSupportStatusCompleted)
                                                _ListChip(
                                                  label: [
                                                    () {
                                                      final day =
                                                          log.visitDate!.trim();
                                                      if (day.length >= 10) {
                                                        final m = int.tryParse(
                                                              day.substring(
                                                                5,
                                                                7,
                                                              ),
                                                            ) ??
                                                            0;
                                                        final d = int.tryParse(
                                                              day.substring(
                                                                8,
                                                                10,
                                                              ),
                                                            ) ??
                                                            0;
                                                        return '방문 $m/$d';
                                                      }
                                                      return '방문 $day';
                                                    }(),
                                                    if ((log.visitTime ?? '')
                                                        .trim()
                                                        .isNotEmpty)
                                                      () {
                                                        final t = log
                                                            .visitTime!
                                                            .trim();
                                                        return t.length >= 5
                                                            ? t.substring(0, 5)
                                                            : t;
                                                      }(),
                                                  ].join(' '),
                                                  color: scheme.tertiary,
                                                ),
                                              if ((log.createdBy ?? '')
                                                  .trim()
                                                  .isNotEmpty)
                                                _ListChip(
                                                  label: log.createdBy!.trim(),
                                                  color: scheme.primary,
                                                ),
                                              if (log.attachmentUrls.isNotEmpty)
                                                _ListChip(
                                                  label:
                                                      '첨부 ${log.attachmentUrls.length}',
                                                  color: accent,
                                                ),
                                            ],
                                          ),
                                          if (cue.action !=
                                              SupportNextAction.done)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                cue.progressLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      cue.action ==
                                                          SupportNextAction
                                                              .visit
                                                      ? scheme.tertiary
                                                      : accent,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: scheme.onSurfaceVariant.withValues(
                                        alpha: 0.55,
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
          ),
        ],
      ),
    );
  }
}

class CustomerSupportReceptionDetailScreen extends ConsumerStatefulWidget {
  const CustomerSupportReceptionDetailScreen({super.key, this.log, this.logId})
    : assert(log != null || logId != null);

  final SupportCallLog? log;
  final String? logId;

  @override
  ConsumerState<CustomerSupportReceptionDetailScreen> createState() =>
      _CustomerSupportReceptionDetailScreenState();
}

class _CustomerSupportReceptionDetailScreenState
    extends ConsumerState<CustomerSupportReceptionDetailScreen> {
  SupportCallLog? _log;
  List<SupportConsultation> _consults = const [];
  List<SupportVisitReport> _visits = const [];
  List<SupportQuoteDocument> _quotes = const [];
  /// 같은 주소의 이전 접수(현재 건 제외).
  List<SupportCallLog> _priorLogs = const [];
  Object? _loadError;
  bool _loading = false;
  bool _changed = false;
  bool _busy = false;
  final _consultPageCtrl = PageController();
  int _consultPage = 0;
  String? _visitTeamLabel;

  @override
  void initState() {
    super.initState();
    _log = widget.log;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _consultPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.logId ?? widget.log?.id;
    if (id == null || id.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = '접수 정보가 없습니다.';
      });
      return;
    }
    if (_log == null) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final repo = ref.read(supportCallLogRepositoryProvider);
      SupportCallLog log;
      try {
        log = await repo.getById(id);
      } catch (e) {
        if (_log == null) rethrow;
        log = _log!;
      }
      List<SupportConsultation> consults = const [];
      List<SupportVisitReport> visits = const [];
      try {
        consults = await repo.listConsultations(id);
      } catch (_) {}
      try {
        visits = await repo.listVisitReports(id);
      } catch (_) {}
      var quotes = <SupportQuoteDocument>[];
      try {
        quotes = await ref
            .read(supportAsQuoteRepositoryProvider)
            .listForReception(
              callLogId: log.id,
              address: log.address,
            );
      } catch (_) {}
      var priorLogs = <SupportCallLog>[];
      final addr = (log.address ?? '').trim();
      if (normalizeSupportAddress(addr).length >= 10) {
        try {
          final recent = await repo.list(limit: 250);
          priorLogs = recent
              .where(
                (e) =>
                    e.id != log.id &&
                    supportAddressesMatch(addr, e.address),
              )
              .toList();
        } catch (_) {}
      }
      String? teamLabel;
      final teamId = (log.visitTeamId ?? '').trim();
      if (teamId.isNotEmpty) {
        try {
          final teams = await ref
              .read(supportAsVisitTeamRepositoryProvider)
              .list(activeOnly: false);
          for (final t in teams) {
            if (t.id == teamId) {
              teamLabel = t.label;
              break;
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _log = log;
        _consults = consults;
        _visits = visits;
        _quotes = quotes;
        _priorLogs = priorLogs;
        _visitTeamLabel = teamLabel;
        _loading = false;
        _consultPage = consults.isEmpty ? 0 : consults.length - 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_consultPageCtrl.hasClients || consults.isEmpty) {
          return;
        }
        _consultPageCtrl.jumpToPage(consults.length - 1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  String _when() {
    return formatSeoulDateTimeDots(_log?.createdAt ?? _log?.callDate);
  }

  void _pop() {
    Navigator.of(context).pop(_changed);
  }

  Future<void> _edit() async {
    final current = _log;
    if (_busy || current == null) return;
    final updated = await Navigator.of(context).push<SupportCallLog>(
      MaterialPageRoute<SupportCallLog>(
        builder: (_) => CustomerSupportIntakeScreen(existing: current),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _log = updated;
      _changed = true;
    });
    unawaited(_load());
  }

  Future<void> _addConsultation() async {
    final current = _log;
    if (current == null || _busy) return;
    final saved = await showSupportFirstConsultationSheet(
      context,
      log: current,
      stage: _consults.length + 1,
      lastOutcome: lastSupportConsultOutcome(
        _consults.map((c) => c.description),
      ),
    );
    if (!mounted || !saved) return;
    setState(() => _changed = true);
    unawaited(_load());
  }

  bool get _showVisitHistory =>
      _visits.isNotEmpty ||
      supportVisitRecordAllowed(
        visitDate: _log?.visitDate,
        serviceStatusId: _log?.serviceStatusId,
        consultationDescriptions: _consults.map((c) => c.description),
        existingVisitReportCount: _visits.length,
      );

  bool get _canAddVisitRecord => supportVisitRecordCanAdd(
    visitDate: _log?.visitDate,
    serviceStatusId: _log?.serviceStatusId,
    consultationDescriptions: _consults.map((c) => c.description),
    existingVisitReportCount: _visits.length,
  );

  bool get _canScheduleVisit {
    final log = _log;
    if (log == null) return false;
    if (log.serviceStatusId == kSupportStatusCompleted) return false;
    if (log.isPending && _consults.isEmpty) return false;
    return true;
  }

  SupportConsultOutcome? get _lastOutcome =>
      lastSupportConsultOutcome(_consults.map((c) => c.description));

  bool get _canWriteOfficialQuote {
    if (_log == null) return false;
    if (_log!.serviceStatusId == kSupportStatusCompleted) return false;
    if (_flowCue.action == SupportNextAction.quote) return true;
    return _lastOutcome == SupportConsultOutcome.verbalQuote;
  }

  SupportConsultation? get _lastQuoteConsult {
    for (final c in _consults.reversed) {
      if (parseSupportConsultation(c.description).outcome ==
          SupportConsultOutcome.quoteSend) {
        return c;
      }
    }
    return null;
  }

  SupportVisitReport? get _unpaidDeposit {
    for (final report in _visits.reversed) {
      if (report.isPaid &&
          !report.depositPaid &&
          (report.depositYmd ?? '').trim().isNotEmpty) {
        return report;
      }
    }
    return null;
  }

  SupportFlowCue get _flowCue {
    final unpaid = _unpaidDeposit;
    final last = lastSupportConsultOutcome(_consults.map((c) => c.description));
    String? sendYmd;
    String? sentYmd;
    for (final c in _consults) {
      final parsed = parseSupportConsultation(c.description);
      if (parsed.outcome == SupportConsultOutcome.quoteSend) {
        sendYmd = parsed.ymd;
        sentYmd = parsed.sentYmd;
      }
    }
    // 상담 문구에 발송일이 없어도, 이 접수에 연결된 견적서가 발송완료면 맞춘다.
    if ((sentYmd ?? '').trim().isEmpty) {
      final logId = (_log?.id ?? '').trim();
      for (final q in _quotes) {
        if (!q.isSent) continue;
        final qLog = (q.callLogId ?? '').trim();
        if (logId.isEmpty || qLog != logId) continue;
        sentYmd = q.sentYmd;
        break;
      }
    }
    var outcome = last;
    if ((sentYmd ?? '').trim().isNotEmpty &&
        (outcome == SupportConsultOutcome.verbalQuote ||
            outcome == SupportConsultOutcome.feedbackWait)) {
      outcome = SupportConsultOutcome.quoteSend;
    }
    return supportFlowCue(
      serviceStatusId: _log?.serviceStatusId,
      consultationCount: _consults.length,
      canAddVisit: _canAddVisitRecord,
      visitDate: _log?.visitDate,
      visitTime: _log?.visitTime,
      depositYmd: unpaid?.depositYmd,
      depositPaid: unpaid == null,
      lastOutcome: outcome,
      quoteSendYmd: sendYmd,
      quoteSentYmd: sentYmd,
    );
  }

  Future<void> _changeVisitSchedule() async {
    final log = _log;
    if (log == null) return;
    final picked = await showSupportVisitDatePicker(
      context,
      log: log,
      selectedYmd: log.visitDate,
      selectedTeamId: log.visitTeamId,
      selectedTime: log.visitTime,
      selectedTeamLabel: _visitTeamLabel,
      confirmChange: true,
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportCallLogRepositoryProvider)
          .updateVisitSchedule(
            callLogId: log.id,
            visitYmd: picked.ymd,
            visitTeamId: picked.teamId,
            visitTime: picked.time,
          );
      invalidateSupportWorkCaches(ref);
      unawaited(refreshSupportDueReminders(ref));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _changed = true;
        _visitTeamLabel = picked.teamLabel;
      });
      unawaited(_load());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문예정일을 바꿨습니다.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _scheduleVisitDirect() async {
    final log = _log;
    if (log == null || _busy) return;
    if ((log.visitDate ?? '').trim().isNotEmpty) {
      await _changeVisitSchedule();
      return;
    }
    final picked = await showSupportVisitDatePicker(context, log: log);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportCallLogRepositoryProvider)
          .addConsultation(
            callLogId: log.id,
            description: supportVisitConsultBody(
              ymd: picked.ymd,
              time: picked.time,
              teamLabel: picked.teamLabel,
            ),
            createdBy: ref.read(authControllerProvider)?.name,
            currentStatusId: log.serviceStatusId,
            outcome: SupportConsultOutcome.visit,
            visitYmd: picked.ymd,
            visitTeamId: picked.teamId,
            visitTime: picked.time,
            visitTeamLabel: picked.teamLabel,
          );
      invalidateSupportWorkCaches(ref);
      unawaited(refreshSupportDueReminders(ref));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _changed = true;
        _visitTeamLabel = picked.teamLabel;
      });
      unawaited(_load());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('방문일을 잡았습니다.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _openQuoteCockpit() async {
    final log = _log;
    if (log == null) return;
    final unsent = _quotes.where((q) => !q.isSent).toList();
    var consult = _lastQuoteConsult;
    if (unsent.isNotEmpty && consult != null) {
      await _exportQuote(consult);
      return;
    }
    if (unsent.isNotEmpty) {
      await _openSiteQuotesSheet();
      return;
    }
    final saved = await pushSupportQuoteEditor(
      context,
      callLogId: log.id,
      site: _siteFromLog(),
    );
    if (!mounted) return;
    if (saved != null) {
      SupportQuoteDocument stored = saved;
      try {
        stored = await ref.read(supportAsQuoteRepositoryProvider).upsert(
          saved,
          editorName: ref.read(authControllerProvider)?.name ??
              ref.read(authControllerProvider)?.id,
        );
      } catch (_) {}
      if (!mounted) return;
      if (consult == null) {
        try {
          await ref
              .read(supportCallLogRepositoryProvider)
              .addConsultation(
                callLogId: log.id,
                description: supportQuoteConsultBody(stored),
                createdBy: ref.read(authControllerProvider)?.name,
                currentStatusId: log.serviceStatusId,
                outcome: SupportConsultOutcome.quoteSend,
                sendYmd: todayYmdSeoul(),
                amount: stored.total > 0 ? stored.total : null,
              );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
          }
        }
      }
      if (!mounted) return;
      final action = await showSupportQuoteExportSheet(context, doc: stored);
      if (action == SupportQuoteViewAction.sent) {
        final day = todayYmdSeoul();
        try {
          await ref
              .read(supportAsQuoteRepositoryProvider)
              .upsert(
                stored.copyWith(sentYmd: day, callLogId: log.id),
                editorName: ref.read(authControllerProvider)?.name ??
                    ref.read(authControllerProvider)?.id,
              );
          await ref
              .read(supportCallLogRepositoryProvider)
              .markLatestQuoteSentForCallLog(
                log.id,
                sentYmd: day,
                createdBy: ref.read(authControllerProvider)?.name,
              );
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() => _changed = true);
    unawaited(_load());
  }

  Future<void> _confirmDeposit() async {
    final report = _unpaidDeposit;
    if (report == null || (report.id ?? '').isEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const CustomerSupportCollectionScreen(initialFilter: 'due'),
        ),
      );
      if (mounted) unawaited(_load());
      return;
    }
    try {
      final next = await nextSupportDepositPaidReport(
        context,
        report: report,
        currentlyPaid: false,
        plannedYmd: report.depositYmd,
      );
      if (next == null || !mounted) return;
      await ref.read(supportCallLogRepositoryProvider).updateVisitReport(next);
      invalidateSupportWorkCaches(ref);
      if (!mounted) return;
      setState(() => _changed = true);
      unawaited(_load());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('입금을 확인했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  SupportQuoteDocument? _quoteForConsult(SupportConsultation consult) {
    if (_quotes.isEmpty) return null;
    final byLog = _quotes
        .where((q) => (q.callLogId ?? '') == (_log?.id ?? ''))
        .toList();
    final pool = byLog.isNotEmpty ? byLog : const <SupportQuoteDocument>[];
    for (final q in pool) {
      final no = q.quoteNo.trim();
      if (no.isNotEmpty && consult.description.contains(no)) return q;
    }
    if (pool.length == 1) return pool.first;
    return null;
  }

  SupportSiteSample _siteFromLog() {
    final log = _log;
    return SupportSiteSample(
      id: log?.id ?? '',
      name: (log?.customerName ?? '').trim(),
      address: log?.address ?? '',
      phone: log?.customerPhone ?? '',
      assignee: log?.createdBy ?? '',
      revisitCount: 0,
      installCompletedYmd: null,
      addresses: [
        if ((log?.address ?? '').trim().isNotEmpty) log!.address!.trim(),
      ],
      history: const [],
      quotes: const [],
      hasBusinessLicense: false,
      hasChecksheet: false,
    );
  }

  List<SupportQuoteDocument> get _siteQuotesOldestFirst {
    final list = List<SupportQuoteDocument>.from(_quotes);
    list.sort((a, b) {
      // 미발송을 위에 두고, 같은 그룹은 작성일 오름차순(1차→N차)
      final bySent = (a.isSent ? 1 : 0).compareTo(b.isSent ? 1 : 0);
      if (bySent != 0) return bySent;
      final ad = a.ymd.trim();
      final bd = b.ymd.trim();
      final byDay = ad.compareTo(bd);
      if (byDay != 0) return byDay;
      return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
    });
    return list;
  }

  int _siteQuoteStage(SupportQuoteDocument q) {
    final chrono = List<SupportQuoteDocument>.from(_quotes)
      ..sort((a, b) {
        final ad = a.ymd.trim();
        final bd = b.ymd.trim();
        final byDay = ad.compareTo(bd);
        if (byDay != 0) return byDay;
        return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
      });
    final i = chrono.indexWhere((e) => e.id == q.id);
    return i < 0 ? chrono.length : i + 1;
  }

  String _siteQuoteLineLabel(SupportQuoteDocument q, int stage) {
    final day = q.ymd.trim().isEmpty ? '날짜 없음' : q.ymd.trim();
    final total = q.total <= 0 ? '-' : formatSupportUnitPriceWon(q.total);
    return '$stage차, $day, $total';
  }

  String _siteQuotesCardSubtitle() {
    final ordered = _siteQuotesOldestFirst;
    if (ordered.isEmpty) return '없음';
    final logId = (_log?.id ?? '').trim();
    final linked = ordered
        .where((e) => (e.callLogId ?? '').trim() == logId)
        .length;
    final byAddr = ordered.length - linked;
    final unsent = ordered.where((e) => !e.isSent).length;
    final parts = <String>[];
    if (linked > 0) parts.add('이 접수 $linked건');
    if (byAddr > 0) parts.add('같은 주소 $byAddr건');
    if (unsent > 0) parts.add('미발송 $unsent');
    if (parts.isEmpty) return '전체 ${ordered.length}건';
    return parts.join(' · ');
  }

  String _priorHistoryCardSubtitle() {
    final addr = (_log?.address ?? '').trim();
    if (normalizeSupportAddress(addr).length < 10) {
      return '주소가 짧아 이전 접수를 찾지 않습니다';
    }
    if (_priorLogs.isEmpty) return '같은 주소 이전 접수 없음';
    return '${_priorLogs.length}건 · ${supportCallLogHistoryLine(_priorLogs.first)}';
  }

  Future<void> _openPriorHistorySheet() async {
    final logs = List<SupportCallLog>.from(_priorLogs);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: false,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final media = MediaQuery.of(ctx);
        final bottomInset = media.viewPadding.bottom;
        final maxH = media.size.height * 0.62;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '같은 주소 이전 접수',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  logs.isEmpty
                      ? '같은 주소로 남은 이전 접수가 없습니다'
                      : '탭하면 해당 접수 상세로 이동합니다',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '새로 접수된 현장이거나, 주소 표기가 달라 못 찾은 경우입니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        final site =
                            parseSupportIssueBody(log.issue).siteName.trim();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.history_rounded,
                            color: AppTokens.customerSupportAccent(scheme),
                          ),
                          title: Text(
                            [
                              if (site.isNotEmpty) site,
                              log.customerName.trim(),
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            supportCallLogHistoryLine(log),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(this.context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CustomerSupportReceptionDetailScreen(
                                      log: log,
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
          ),
        );
      },
    );
  }

  Future<void> _openSiteQuotesSheet() async {
    final host = context;
    final ordered = _siteQuotesOldestFirst;
    final unsentCount = ordered.where((e) => !e.isSent).length;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: false,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final media = MediaQuery.of(ctx);
        // Android 3버튼/제스처 바와 겹치지 않도록 viewPadding 기준 하단 여백.
        final bottomInset = media.viewPadding.bottom;
        final maxH = media.size.height * 0.62;
        final warn = scheme.error;
        final ok = AppTokens.success(scheme);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '이 주소 견적서',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  ordered.isEmpty
                      ? '이 접수·같은 주소 견적이 없습니다'
                      : unsentCount > 0
                      ? '미발송 $unsentCount건 · 탭하면 상세 · 이미지/PDF/이메일'
                      : '모두 발송 완료 · 탭하면 상세',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: unsentCount > 0 ? warn : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                if (ordered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '이 접수에 연결됐거나, 주소가 같은 견적서가 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: ordered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final q = ordered[i];
                        final stage = _siteQuoteStage(q);
                        final sent = q.isSent;
                        final statusColor = sent ? ok : warn;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _siteQuoteLineLabel(q, stage),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              sent
                                  ? '발송완료 ${q.sentYmd!.trim()}'
                                  : '미발송 · 작성만 됨',
                              if (q.hasCloudPdf) '클라우드 PDF',
                              supportQuoteAuditLine(q),
                            ].where((e) => e.trim().isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  sent ? '발송' : '미발송',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final action = await showSupportQuoteExportSheet(
                              host,
                              doc: q,
                            );
                            if (!mounted) return;
                            if (action == SupportQuoteViewAction.edit) {
                              final edited = await pushSupportQuoteEditor(
                                context,
                                existing: q,
                                callLogId: _log?.id,
                                site: _siteFromLog(),
                              );
                              if (edited != null) {
                                try {
                                  await ref
                                      .read(supportAsQuoteRepositoryProvider)
                                      .upsert(
                                        edited,
                                        editorName:
                                            ref.read(authControllerProvider)?.name ??
                                            ref.read(authControllerProvider)?.id,
                                      );
                                } catch (_) {}
                              }
                              unawaited(_load());
                              return;
                            }
                            if (action == SupportQuoteViewAction.sent) {
                              final day = todayYmdSeoul();
                              try {
                                await ref
                                    .read(supportAsQuoteRepositoryProvider)
                                    .upsert(
                                      q.copyWith(
                                        sentYmd: day,
                                        callLogId: _log?.id ?? q.callLogId,
                                      ),
                                      editorName:
                                          ref.read(authControllerProvider)?.name ??
                                          ref.read(authControllerProvider)?.id,
                                    );
                                final logId = (_log?.id ?? '').trim();
                                if (logId.isNotEmpty) {
                                  await ref
                                      .read(supportCallLogRepositoryProvider)
                                      .markLatestQuoteSentForCallLog(
                                        logId,
                                        sentYmd: day,
                                        createdBy: ref
                                            .read(authControllerProvider)
                                            ?.name,
                                      );
                                }
                              } catch (_) {}
                              unawaited(_load());
                            }
                            if (action == SupportQuoteViewAction.unsent) {
                              try {
                                await ref
                                    .read(supportAsQuoteRepositoryProvider)
                                    .upsert(
                                      q.copyWith(clearSentYmd: true),
                                      editorName:
                                          ref.read(authControllerProvider)?.name ??
                                          ref.read(authControllerProvider)?.id,
                                    );
                              } catch (_) {}
                              unawaited(_load());
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportQuote(SupportConsultation consult) async {
    var quote = _quoteForConsult(consult);
    if (quote == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SupportQuoteWriterScreen(
            callLogId: _log?.id,
            site: _siteFromLog(),
          ),
        ),
      );
      if (mounted) unawaited(_load());
      return;
    }
    final action = await showSupportQuoteExportSheet(context, doc: quote);
    if (!mounted) return;
    if (action == SupportQuoteViewAction.edit) {
      final edited = await pushSupportQuoteEditor(
        context,
        existing: quote,
        callLogId: _log?.id,
        site: _siteFromLog(),
      );
      if (edited != null) {
        try {
          await ref.read(supportAsQuoteRepositoryProvider).upsert(
            edited,
            editorName: ref.read(authControllerProvider)?.name ??
                ref.read(authControllerProvider)?.id,
          );
        } catch (_) {}
      }
      unawaited(_load());
      return;
    }
    if (action == SupportQuoteViewAction.unsent) {
      try {
        await ref
            .read(supportAsQuoteRepositoryProvider)
            .upsert(
              quote.copyWith(clearSentYmd: true),
              editorName: ref.read(authControllerProvider)?.name ??
                  ref.read(authControllerProvider)?.id,
            );
      } catch (_) {}
      if (!mounted) return;
      setState(() => _changed = true);
      unawaited(_load());
      return;
    }
    if (action != SupportQuoteViewAction.sent) return;
    final day = todayYmdSeoul();
    try {
      await ref
          .read(supportAsQuoteRepositoryProvider)
          .upsert(
            quote.copyWith(
              sentYmd: day,
              callLogId: _log?.id ?? quote.callLogId,
            ),
            editorName: ref.read(authControllerProvider)?.name ??
                ref.read(authControllerProvider)?.id,
          );
      final logId = (_log?.id ?? '').trim();
      if (logId.isNotEmpty) {
        await ref.read(supportCallLogRepositoryProvider).markLatestQuoteSentForCallLog(
          logId,
          sentYmd: day,
          createdBy: ref.read(authControllerProvider)?.name,
        );
      } else {
        await ref.read(supportCallLogRepositoryProvider).markQuoteSent(
          consultationId: consult.id,
          description: consult.description,
          sentYmd: day,
        );
      }
      unawaited(refreshSupportDueReminders(ref));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _changed = true);
    unawaited(_load());
  }

  Future<void> _toggleQuoteSent(SupportConsultation consult) async {
    final parsed = parseSupportConsultation(consult.description);
    final quote = _quoteForConsult(consult);
    try {
      String? sentYmd;
      if ((parsed.sentYmd ?? '').isEmpty && !(quote?.isSent ?? false)) {
        sentYmd = await askSupportQuoteSentYmd(context, plannedYmd: parsed.ymd);
        if (sentYmd == null || !mounted) return;
      }
      await ref
          .read(supportCallLogRepositoryProvider)
          .markQuoteSent(
            consultationId: consult.id,
            description: consult.description,
            sentYmd: sentYmd,
          );
      if (quote != null) {
        await ref
            .read(supportAsQuoteRepositoryProvider)
            .upsert(
              sentYmd == null
                  ? quote.copyWith(clearSentYmd: true)
                  : quote.copyWith(sentYmd: sentYmd),
              editorName: ref.read(authControllerProvider)?.name ??
                  ref.read(authControllerProvider)?.id,
            );
      }
      unawaited(refreshSupportDueReminders(ref));
      if (!mounted) return;
      setState(() => _changed = true);
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _addVisitReport() async {
    final current = _log;
    if (current == null || _busy) return;
    if (!_canAddVisitRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _log?.serviceStatusId == kSupportStatusCompleted
                ? '완료된 접수는 방문 기록을 추가할 수 없습니다.'
                : '방문 요청으로 일정이 잡힌 뒤에 방문 기록을 남길 수 있습니다.',
          ),
        ),
      );
      return;
    }
    final saved = await showSupportVisitReportSheet(context, log: current);
    if (!mounted || !saved) return;
    setState(() => _changed = true);
    unawaited(_load());
  }

  Future<void> _delete() async {
    final current = _log;
    if (_busy || current == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('접수 삭제'),
          content: const Text('이 A/S 접수를 삭제할까요? 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(supportCallLogRepositoryProvider).delete(current.id);
      invalidateSupportWorkCaches(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A/S 접수를 삭제했습니다.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  String _visitScheduleLabel() {
    final day = (_log?.visitDate ?? '').trim();
    if (day.isEmpty) return '아직 없음';
    final parts = <String>[];
    if (day.length >= 10) {
      final m = int.tryParse(day.substring(5, 7)) ?? 0;
      final d = int.tryParse(day.substring(8, 10)) ?? 0;
      parts.add('$m월 $d일');
    } else {
      parts.add(day);
    }
    final time = (_log?.visitTime ?? '').trim();
    if (time.isNotEmpty) {
      parts.add(time.length >= 5 ? time.substring(0, 5) : time);
    }
    final team = (_visitTeamLabel ?? '').trim();
    if (team.isNotEmpty) parts.add(team);
    return parts.join(' · ');
  }

  SupportIssueFields get _parsed => parseSupportIssueBody(_log?.issue ?? '');

  Color _urgencyColor(ColorScheme scheme) => switch (_parsed.urgency) {
    SupportUrgency.high => scheme.error,
    SupportUrgency.mid => const Color(0xFFD97706),
    SupportUrgency.low => AppTokens.success(scheme),
  };

  String get _urgencyLabel => switch (_parsed.urgency) {
    SupportUrgency.high => '상',
    SupportUrgency.mid => '중',
    SupportUrgency.low => '하',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgency = _urgencyColor(scheme);
    final phone = _log?.customerPhone ?? '';
    final address = (_log?.address ?? '').trim();
    final hasPhone = normalizePhoneDigits(phone).length >= 8;
    final cue = _flowCue;
    final pending = _log?.isPending ?? true;
    final completed = _log?.serviceStatusId == kSupportStatusCompleted;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _pop();
      },
      child: Scaffold(
        backgroundColor: Color.lerp(scheme.surface, urgency, 0.10),
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('접수 상세'),
          ),
          titleSpacing: 8,
          backgroundColor: urgency,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_busy || _loading)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else if (_log != null) ...[
              IconButton(
                tooltip: 'A/S 단가표',
                onPressed: () => openSupportUnitPriceLookup(context),
                icon: const Icon(Icons.grid_on_rounded),
              ),
              IconButton(
                tooltip: '수정',
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        bottomNavigationBar: _log == null
            ? null
            : UxActionDock(
                children: [
                  UxDockButton(
                    icon: Icons.call_rounded,
                    label: '전화',
                    emphasized: pending,
                    enabled: hasPhone,
                    color: AppTokens.success(scheme),
                    onPressed: hasPhone
                        ? () => LauncherUtils.makePhoneCall(phone)
                        : null,
                  ),
                  if (!_canWriteOfficialQuote ||
                      cue.action == SupportNextAction.quote)
                    UxDockButton(
                      icon: Icons.message_rounded,
                      label: '문자',
                      enabled: hasPhone,
                      onPressed: hasPhone
                          ? () => LauncherUtils.sendSMS(phone)
                          : null,
                    ),
                  if (!completed &&
                      cue.action != SupportNextAction.quote &&
                      cue.action != SupportNextAction.visit &&
                      cue.action != SupportNextAction.deposit)
                    UxDockButton(
                      icon: Icons.add_comment_rounded,
                      label: '${_consults.length + 1}차 상담',
                      emphasized: cue.action == SupportNextAction.consult,
                      onPressed: _addConsultation,
                    ),
                  if (_canWriteOfficialQuote)
                    UxDockButton(
                      icon: Icons.request_quote_outlined,
                      label: '견적서',
                      emphasized: cue.action == SupportNextAction.quote,
                      onPressed: () => unawaited(_openQuoteCockpit()),
                    ),
                  if (cue.action == SupportNextAction.deposit)
                    UxDockButton(
                      icon: Icons.payments_outlined,
                      label: '입금확인',
                      emphasized: true,
                      onPressed: () => unawaited(_confirmDeposit()),
                    ),
                  if (_canAddVisitRecord)
                    UxDockButton(
                      icon: Icons.home_repair_service_outlined,
                      label: '방문기록',
                      emphasized: cue.action == SupportNextAction.visit,
                      onPressed: _addVisitReport,
                    )
                  else if (_canScheduleVisit &&
                      cue.action != SupportNextAction.quote)
                    UxDockButton(
                      icon: Icons.event_available_rounded,
                      label: (_log?.visitDate ?? '').trim().isEmpty
                          ? '방문일'
                          : '일정변경',
                      onPressed: () => unawaited(_scheduleVisitDirect()),
                    ),
                  if (cue.action == SupportNextAction.quote &&
                      _canScheduleVisit)
                    UxDockButton(
                      icon: Icons.event_available_rounded,
                      label: '방문일',
                      onPressed: () => unawaited(_scheduleVisitDirect()),
                    ),
                ],
              ),
        body: _loading
            ? const AppLoading(message: '접수를 불러오는 중…')
            : _loadError != null && _log == null
            ? AppEmpty(
                icon: Icons.cloud_off_outlined,
                message: '접수를 불러오지 못했습니다.',
                detail: koreanErrorMessage(_loadError!),
                actionLabel: '다시 시도',
                onAction: () => unawaited(_load()),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  if (cue.action != SupportNextAction.done) ...[
                    UxStatusHeroBanner(
                      title: cue.title,
                      subtitle: cue.subtitle,
                      icon: switch (cue.action) {
                        SupportNextAction.consult => Icons.add_comment_rounded,
                        SupportNextAction.quote => Icons.request_quote_outlined,
                        SupportNextAction.visit =>
                          Icons.home_repair_service_outlined,
                        SupportNextAction.deposit => Icons.payments_outlined,
                        SupportNextAction.done => Icons.check_circle_outline,
                      },
                      actionLabel: cue.actionLabel,
                      tone: switch (cue.action) {
                        SupportNextAction.consult ||
                        SupportNextAction.visit => UxStatusHeroTone.attention,
                        SupportNextAction.quote ||
                        SupportNextAction.deposit => UxStatusHeroTone.info,
                        SupportNextAction.done => UxStatusHeroTone.neutral,
                      },
                      onTap: () {
                        switch (cue.action) {
                          case SupportNextAction.consult:
                            unawaited(_addConsultation());
                          case SupportNextAction.quote:
                            unawaited(_openQuoteCockpit());
                          case SupportNextAction.visit:
                            unawaited(_addVisitReport());
                          case SupportNextAction.deposit:
                            unawaited(_confirmDeposit());
                          case SupportNextAction.done:
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  _UrgencyBanner(
                    color: urgency,
                    label: _urgencyLabel,
                    product: _parsed.productName,
                  ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label(scheme, '문의 내용'),
                        Text(
                          _parsed.body.trim().isEmpty ? '-' : _parsed.body,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _label(scheme, '상담내용'),
                            const Spacer(),
                            if (_consults.isNotEmpty)
                              Text(
                                '${_consultPage + 1}차 / ${_consults.length}차 · 좌우로 넘김',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (_consults.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _addConsultation,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('1차 상담 입력'),
                            ),
                          )
                        else ...[
                          SizedBox(
                            // 페이지 넘기는 동안에도 견적 슬라이드가 잘리지 않도록
                            // 현재 페이지가 아니라 전체 중 최대 높이 사용.
                            height: _consultPageHeight(),
                            child: PageView.builder(
                              controller: _consultPageCtrl,
                              itemCount: _consults.length,
                              onPageChanged: (i) =>
                                  setState(() => _consultPage = i),
                              itemBuilder: (context, i) {
                                return _consultSlide(scheme, i);
                              },
                            ),
                          ),
                          if (_consults.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < _consults.length; i++)
                                    Container(
                                      width: i == _consultPage ? 16 : 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: i == _consultPage
                                            ? AppTokens.customerSupportAccent(
                                                scheme,
                                              )
                                            : scheme.outlineVariant,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _compactContactCard(
                    scheme: scheme,
                    urgency: urgency,
                    phone: phone,
                    address: address,
                  ),
                  if (_canScheduleVisit)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _DetailCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label(scheme, '방문예정일'),
                                  Text(
                                    _visitScheduleLabel(),
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_scheduleVisitDirect()),
                              icon: const Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                              ),
                              label: Text(
                                (_log?.visitDate ?? '').trim().isEmpty
                                    ? '잡기'
                                    : '변경',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openPriorHistorySheet,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: AppTokens.customerSupportAccent(scheme),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '같은 주소 이전 접수',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _priorHistoryCardSubtitle(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _priorLogs.isEmpty
                                            ? scheme.onSurfaceVariant
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_priorLogs.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '${_priorLogs.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: AppTokens.customerSupportAccent(
                                        scheme,
                                      ),
                                    ),
                                  ),
                                ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openSiteQuotesSheet,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.request_quote_outlined,
                                color: AppTokens.customerSupportAccent(scheme),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '이 주소 견적서',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      _siteQuotesCardSubtitle(),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            _quotes.any((e) => !e.isSent)
                                            ? scheme.error
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_showVisitHistory) ...[
                    const SizedBox(height: 10),
                    _DetailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label(scheme, '방문 기록'),
                          if (_visits.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '방문 후 완료·유무상을 남깁니다. 미완료면 다음 방문일을 잡고, 유상이면 입금예정일과 실제 입금일을 따로 남깁니다.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (_canAddVisitRecord)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: _addVisitReport,
                                      child: const Text('방문 기록 입력'),
                                    ),
                                  ),
                              ],
                            )
                          else
                            for (var i = 0; i < _visits.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _VisitReportTile(
                                report: _visits[i],
                                index: i + 1,
                              ),
                            ],
                        ],
                      ),
                    ),
                  ],
                  if ((_log?.attachmentUrls ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DetailCard(
                      child: SalesCallAttachmentsStrip(
                        urls: _log!.attachmentUrls,
                        saveNamePrefix: _log!.customerName,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _consultSlide(ColorScheme scheme, int i) {
    final consult = _consults[i];
    final parsed = parseSupportConsultation(consult.description);
    if (parsed.outcome == SupportConsultOutcome.quoteSend) {
      return _quoteConsultSlide(scheme, i, consult);
    }
    final bodyText = () {
      final body = parsed.body.trim();
      if (body.isNotEmpty) return body;
      if (parsed.outcome == SupportConsultOutcome.visit &&
          (parsed.ymd ?? '').isNotEmpty) {
        return supportVisitConsultBody(
          ymd: parsed.ymd!,
          time: parsed.visitTime ?? '',
        );
      }
      return consult.description;
    }();
    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${i + 1}차',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (parsed.outcome != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _ListChip(
                  label: supportConsultOutcomeLabel(parsed.outcome!),
                  color: scheme.primary,
                ),
                if ((parsed.ymd ?? '').isNotEmpty)
                  _ListChip(
                    label: [
                      if (parsed.outcome == SupportConsultOutcome.visit)
                        '방문',
                      parsed.ymd!,
                      if ((parsed.visitTime ?? '').isNotEmpty)
                        parsed.visitTime!,
                    ].join(' '),
                    color: scheme.tertiary,
                  ),
                if (parsed.amount != null && parsed.amount! > 0)
                  _ListChip(
                    label: formatSupportUnitPriceWon(parsed.amount),
                    color: AppTokens.info(scheme),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            bodyText,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          if ((consult.createdBy ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '상담 ${consult.createdBy!.trim()}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  double _consultPageHeight() {
    for (final consult in _consults) {
      final parsed = parseSupportConsultation(consult.description);
      if (parsed.outcome == SupportConsultOutcome.quoteSend) {
        return 280;
      }
    }
    return 210;
  }

  Widget _quoteConsultSlide(
    ColorScheme scheme,
    int i,
    SupportConsultation consult,
  ) {
    final parsed = parseSupportConsultation(consult.description);
    final quote = _quoteForConsult(consult);
    final total = quote?.total ?? parsed.amount ?? 0;
    final planned = (parsed.ymd ?? '').trim();
    final sent = (parsed.sentYmd ?? quote?.sentYmd ?? '').trim();
    final isSent = sent.isNotEmpty;
    final accent = AppTokens.customerSupportAccent(scheme);
    final today = todayYmdSeoul();
    final overdue = !isSent && planned.isNotEmpty && planned.compareTo(today) < 0;
    final dueToday = !isSent && planned == today;
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => unawaited(_exportQuote(consult)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${i + 1}차 · 정식 견적서',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isSent ? AppTokens.success(scheme) : scheme.error)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isSent ? '발송완료' : '미발송',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isSent
                            ? AppTokens.success(scheme)
                            : scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                total > 0 ? formatSupportUnitPriceWon(total) : '금액 없음',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              _quoteMetaRow(
                scheme,
                label: '발송예정',
                value: planned.isEmpty
                    ? '미정'
                    : overdue
                    ? '$planned · 지남'
                    : dueToday
                    ? '$planned · 오늘'
                    : planned,
                valueColor: overdue || dueToday
                    ? scheme.error
                    : scheme.onSurface,
              ),
              const SizedBox(height: 4),
              _quoteMetaRow(
                scheme,
                label: '실제발송',
                value: isSent ? sent : '아직 안 보냄',
                valueColor: isSent
                    ? AppTokens.success(scheme)
                    : scheme.error,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => unawaited(_toggleQuoteSent(consult)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      isSent ? '미발송으로' : '발송완료로',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '탭하면 견적서 상세',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if ((consult.createdBy ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '상담 ${consult.createdBy!.trim()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quoteMetaRow(
    ColorScheme scheme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactContactCard({
    required ColorScheme scheme,
    required Color urgency,
    required String phone,
    required String address,
  }) {
    final site = _parsed.siteName.trim();
    final name = (_log?.customerName ?? '').trim();
    final title = site.isNotEmpty ? site : (name.isEmpty ? '-' : name);
    final phoneLabel = phone.trim().isEmpty
        ? ''
        : formatKoreanPhoneHyphenated(phone);
    final createdBy = (_log?.createdBy ?? '').trim();
    final meta = [
      if (createdBy.isNotEmpty) createdBy,
      _when(),
    ].join(' · ');

    final identityBits = <String>[
      if (site.isNotEmpty && name.isNotEmpty) name,
      if (phoneLabel.isNotEmpty) phoneLabel,
    ];

    return _DetailCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          if (identityBits.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              identityBits.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Material(
              color: urgency.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SupportSitesMapScreen(
                        focusLog: _log,
                        pendingOnly: true,
                      ),
                    ),
                  );
                },
                onLongPress: () => LauncherUtils.openAddressMap(address),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 15, color: urgency),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: urgency,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _VisitReportTile extends StatelessWidget {
  const _VisitReportTile({required this.report, required this.index});

  final SupportVisitReport report;
  final int index;

  String get _whenLabel {
    final time = (report.visitTime ?? '').trim();
    final timeLabel = time.isEmpty
        ? ''
        : (time.length >= 5 ? time.substring(0, 5) : time);
    final scheduled = (report.scheduledYmd ?? '').trim();
    final scheduledTime = (report.scheduledTime ?? '').trim();
    final scheduledTimeLabel = scheduledTime.isEmpty
        ? ''
        : (scheduledTime.length >= 5
              ? scheduledTime.substring(0, 5)
              : scheduledTime);
    final actual = [
      '$index회 · 실제 ${report.visitYmd}',
      if (timeLabel.isNotEmpty) timeLabel,
    ].join(' ');
    if (scheduled.isEmpty || scheduled == report.visitYmd) return actual;
    return [
      actual,
      '예정 $scheduled${scheduledTimeLabel.isEmpty ? '' : ' $scheduledTimeLabel'}',
    ].join(' · ');
  }

  Future<void> _openDetail(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final doneColor = report.completed
        ? AppTokens.success(scheme)
        : scheme.error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: false,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _whenLabel,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ListChip(
                      label: report.completed ? '완료' : '미완료',
                      color: doneColor,
                    ),
                    _ListChip(
                      label: report.isPaid
                          ? '유상 ${formatSupportUnitPriceWon(report.amount)}'
                          : '무상',
                      color: report.isPaid
                          ? const Color(0xFFD97706)
                          : scheme.primary,
                    ),
                    if ((report.depositYmd ?? '').isNotEmpty)
                      _ListChip(
                        label: report.depositPaid
                            ? [
                                '입금완료 ${report.effectiveDepositPaidYmd ?? report.depositYmd}',
                                if ((report.depositYmd ?? '') !=
                                    (report.effectiveDepositPaidYmd ?? ''))
                                  '예정 ${report.depositYmd}',
                              ].join(' · ')
                            : '입금예정 ${report.depositYmd}',
                        color: report.depositPaid
                            ? AppTokens.success(scheme)
                            : const Color(0xFF059669),
                      ),
                    if ((report.nextVisitYmd ?? '').isNotEmpty)
                      _ListChip(
                        label: [
                          '다음방문 ${report.nextVisitYmd}',
                          if ((report.nextVisitTime ?? '').trim().isNotEmpty)
                            (report.nextVisitTime!.trim().length >= 5
                                ? report.nextVisitTime!.trim().substring(0, 5)
                                : report.nextVisitTime!.trim()),
                        ].join(' '),
                        color: scheme.error,
                      ),
                    for (final part in report.parts)
                      _ListChip(label: part, color: scheme.secondary),
                  ],
                ),
                if (report.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '방문 내용',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.notes,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
                if ((report.createdBy ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '방문 ${report.createdBy!.trim()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (report.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SalesCallAttachmentsStrip(urls: report.photoUrls),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _whenLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (report.isPaid)
                          _ListChip(
                            label:
                                '유상 ${formatSupportUnitPriceWon(report.amount)}',
                            color: const Color(0xFFD97706),
                          )
                        else
                          _ListChip(label: '무상', color: scheme.primary),
                        if (report.isPaid &&
                            (report.depositYmd ?? '').isNotEmpty)
                          _ListChip(
                            label: report.depositPaid
                                ? (report.effectiveDepositPaidYmd ==
                                          report.depositYmd
                                      ? '입금완료 ${report.effectiveDepositPaidYmd}'
                                      : '입금완료 ${report.effectiveDepositPaidYmd} · 예정 ${report.depositYmd}')
                                : '입금예정 ${report.depositYmd}',
                            color: report.depositPaid
                                ? AppTokens.success(scheme)
                                : const Color(0xFF059669),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListChip extends StatelessWidget {
  const _ListChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _UrgencyBanner extends StatelessWidget {
  const _UrgencyBanner({
    required this.color,
    required this.label,
    required this.product,
  });

  final Color color;
  final String label;
  final String product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '긴급도 $label',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (product.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
