import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/core/widgets/ux_action_dock.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_widgets.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_schedule_calendar_screen.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/customer_support/support_first_consultation_sheet.dart';
import 'package:coad_customer_calls/features/customer_support/support_visit_report_sheet.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/features/sales_calls/widgets/sales_call_attachments.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerSupportReceptionListScreen extends ConsumerStatefulWidget {
  const CustomerSupportReceptionListScreen({
    super.key,
    this.title = 'A/S 접수내역',
    this.fromYmd,
    this.toYmdInclusive,
    this.pendingOnly = false,
    this.visitOnly = false,
  });

  final String title;
  final String? fromYmd;
  final String? toYmdInclusive;
  final bool pendingOnly;
  final bool visitOnly;

  @override
  ConsumerState<CustomerSupportReceptionListScreen> createState() =>
      _CustomerSupportReceptionListScreenState();
}

class _CustomerSupportReceptionListScreenState
    extends ConsumerState<CustomerSupportReceptionListScreen> {
  final _queryCtrl = TextEditingController();
  List<SupportCallLog> _items = const [];
  bool _loading = true;
  Object? _error;
  String _query = '';
  String _branchTab = '전체';

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

  List<SupportCallLog> get _filtered {
    final q = _query.trim().toLowerCase();
    final source = _branchTab == '전체'
        ? _items
        : _items
              .where((e) => _branchOf(e) == _branchTab)
              .toList(growable: false);
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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref
          .read(supportCallLogRepositoryProvider)
          .list(
            fromYmd: widget.fromYmd,
            toYmdInclusive: widget.toYmdInclusive,
            pendingOnly: widget.pendingOnly,
            visitOnly: widget.visitOnly,
          );
      if (!mounted) return;
      setState(() {
        _items = rows;
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerSupportIntakeScreen(),
      ),
    );
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
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '방문·발송 달력',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CustomerSupportScheduleCalendarScreen(),
                ),
              );
              if (mounted) unawaited(_reload());
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : () => unawaited(_reload()),
            icon: const Icon(Icons.refresh_rounded),
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
                                              if (log.isPending)
                                                _ListChip(
                                                  label: '미처리',
                                                  color: scheme.error,
                                                ),
                                              if ((log.visitDate ?? '')
                                                  .isNotEmpty)
                                                _ListChip(
                                                  label: '방문 ${log.visitDate}',
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
  Object? _loadError;
  bool _loading = false;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _log = widget.log;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
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
      if (!mounted) return;
      setState(() {
        _log = log;
        _consults = consults;
        _visits = visits;
        _loading = false;
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
    );
    if (!mounted || !saved) return;
    setState(() => _changed = true);
    unawaited(_load());
  }

  Future<void> _addVisitReport() async {
    final current = _log;
    if (current == null || _busy) return;
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
      ref.invalidate(supportHomeStatsProvider);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _pop();
      },
      child: Scaffold(
        backgroundColor: Color.lerp(scheme.surface, urgency, 0.10),
        appBar: AppBar(
          title: const Text('접수 상세'),
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
              TextButton(
                onPressed: _edit,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('수정'),
              ),
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('삭제'),
              ),
            ],
          ],
        ),
        bottomNavigationBar: _log == null
            ? null
            : UxActionDock(
                flexes: const [2, 2, 3, 3],
                children: [
                  UxDockButton(
                    icon: Icons.call_rounded,
                    label: '전화',
                    emphasized: true,
                    enabled: hasPhone,
                    color: AppTokens.success(scheme),
                    onPressed: hasPhone
                        ? () => LauncherUtils.makePhoneCall(phone)
                        : null,
                  ),
                  UxDockButton(
                    icon: Icons.message_rounded,
                    label: '문자',
                    enabled: hasPhone,
                    onPressed: hasPhone
                        ? () => LauncherUtils.sendSMS(phone)
                        : null,
                  ),
                  UxDockButton(
                    icon: Icons.add_comment_rounded,
                    label: '${_consults.length + 1}차 상담',
                    onPressed: _addConsultation,
                  ),
                  UxDockButton(
                    icon: Icons.home_repair_service_outlined,
                    label: '방문 기록',
                    emphasized: true,
                    onPressed: _addVisitReport,
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
                        if (_parsed.siteName.isNotEmpty) ...[
                          _label(scheme, '현장명'),
                          Text(
                            _parsed.siteName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _label(scheme, '이름'),
                        Text(
                          (_log?.customerName ?? '').trim().isEmpty
                              ? '-'
                              : _log!.customerName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label(scheme, '전화번호'),
                        Text(
                          phone.trim().isEmpty
                              ? '-'
                              : formatKoreanPhoneHyphenated(phone),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label(scheme, '주소'),
                        Material(
                          color: address.isEmpty
                              ? Colors.transparent
                              : urgency.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: address.isEmpty
                                ? null
                                : () => LauncherUtils.openAddressMap(address),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    color: address.isEmpty
                                        ? scheme.onSurfaceVariant
                                        : urgency,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      address.isEmpty ? '-' : address,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                        color: address.isEmpty
                                            ? scheme.onSurfaceVariant
                                            : scheme.onSurface,
                                        decoration: address.isEmpty
                                            ? null
                                            : TextDecoration.underline,
                                        decorationColor: urgency.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (address.isNotEmpty)
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                      color: urgency,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (address.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '탭하면 지도가 열립니다',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
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
                        _label(scheme, '접수한 사람'),
                        Text(
                          (_log?.createdBy ?? '').trim().isEmpty
                              ? '-'
                              : _log!.createdBy!.trim(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _label(scheme, '접수 시각'),
                        Text(
                          _when(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
                        _label(scheme, '문의 내용'),
                        Text(
                          _parsed.body.trim().isEmpty ? '-' : _parsed.body,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
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
                        _label(scheme, '상담내용'),
                        if (_consults.isEmpty)
                          Text(
                            '아직 상담 내용이 없습니다. 입력하면 미처리에서 빠집니다.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          for (var i = 0; i < _consults.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final parsed = parseSupportConsultation(
                                  _consults[i].description,
                                );
                                return Column(
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
                                        children: [
                                          _ListChip(
                                            label: supportConsultOutcomeLabel(
                                              parsed.outcome!,
                                            ),
                                            color: scheme.primary,
                                          ),
                                          if ((parsed.ymd ?? '').isNotEmpty)
                                            _ListChip(
                                              label: parsed.ymd!,
                                              color: scheme.tertiary,
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      parsed.body.isEmpty
                                          ? _consults[i].description
                                          : parsed.body,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                      ),
                                    ),
                                    if ((_consults[i].createdBy ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '상담 ${_consults[i].createdBy!.trim()}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label(scheme, '방문 기록'),
                        if (_visits.isEmpty)
                          Text(
                            '방문 후 유무상·부품·완료 여부를 남기면 현장 이력이 됩니다.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          for (var i = 0; i < _visits.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _VisitReportTile(report: _visits[i], index: i + 1),
                          ],
                      ],
                    ),
                  ),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneColor = report.completed
        ? AppTokens.success(scheme)
        : scheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$index회 · ${report.visitYmd}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _ListChip(label: report.completed ? '완료' : '미완료', color: doneColor),
            _ListChip(
              label: report.isPaid ? '유상 ${report.amount}원' : '무상',
              color: report.isPaid ? const Color(0xFFD97706) : scheme.primary,
            ),
            if ((report.depositYmd ?? '').isNotEmpty)
              _ListChip(
                label: '입금 ${report.depositYmd}',
                color: scheme.tertiary,
              ),
            if ((report.nextVisitYmd ?? '').isNotEmpty)
              _ListChip(
                label: '다음방문 ${report.nextVisitYmd}',
                color: scheme.error,
              ),
            for (final part in report.parts)
              _ListChip(label: part, color: scheme.secondary),
          ],
        ),
        if (report.notes.isNotEmpty) ...[
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
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '방문 ${report.createdBy!.trim()}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        if (report.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SalesCallAttachmentsStrip(urls: report.photoUrls),
        ],
      ],
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '긴급도 $label',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (product.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
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
  const _DetailCard({required this.child});

  final Widget child;

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
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}
