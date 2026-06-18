import 'dart:convert';

import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/tax_invoice_calc.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum IssuanceDomain { taxInvoice, performanceBond }

/// 웹 `IssuanceInnerTab` 과 대응 (Flutter 메인 UI는 request / all / issued 만 사용).
enum IssuanceRowKind { request, partial, completed, issued, cancelled }

typedef IssuanceLaunchTarget = ({
  IssuanceDomain domain,
  bool showCompleted,
  String? masterId,
  String? issueId,
  IssuanceListKind? listKind,
});
final pendingIssuanceLaunchProvider = StateProvider<IssuanceLaunchTarget?>(
  (ref) => null,
);

class IssuanceRequestRow {
  IssuanceRequestRow({
    required this.master,
    required this.issue,
    required this.domain,
    required this.kind,
    this.issuedPct = 0,
    this.remainingPct = 0,
  });

  final Map<String, dynamic> master;
  final Map<String, dynamic>? issue;
  final IssuanceDomain domain;
  final IssuanceRowKind kind;
  final double issuedPct;
  final double remainingPct;

  bool get isCompleted =>
      kind == IssuanceRowKind.issued ||
      kind == IssuanceRowKind.completed ||
      kind == IssuanceRowKind.partial;

  bool get isRequest => kind == IssuanceRowKind.request;

  bool get isPartial => kind == IssuanceRowKind.partial;

  DateTime get createdAt {
    final raw = issue?['created_at'] ?? master['created_at'];
    return DateTime.tryParse((raw ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get createdAtText {
    final dt = createdAt;
    if (dt.millisecondsSinceEpoch == 0) return '날짜 없음';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get title {
    if (domain == IssuanceDomain.taxInvoice) {
      return (master['customer_name'] ?? '세금계산서 요청').toString();
    }
    return (master['company_name'] ?? master['bond_type'] ?? '이행증권 요청')
        .toString();
  }

  String get subtitle {
    final requester = (master['requester'] ?? master['created_by'] ?? '')
        .toString();
    final status = _statusLabel((master['status'] ?? '').toString());
    if (isPartial && domain == IssuanceDomain.taxInvoice) {
      return '부분발급 · ${remainingPct.round()}% 남음 · 담당: $requester';
    }
    return '상태: $status${requester.isNotEmpty ? ' · 담당: $requester' : ''}';
  }

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return '대기';
      case 'in_progress':
      case 'inprogress':
        return '진행중';
      case 'completed':
      case 'complete':
        return '완료';
      case 'cancelled':
      case 'canceled':
      case 'cancel':
        return '취소';
      default:
        return raw.isEmpty ? '-' : raw;
    }
  }

  bool get isCancelled => IssuanceRequestService.isCancelledStatus(
    (master['status'] ?? '').toString(),
  );
}

String issuanceRequestOwnerName(IssuanceRequestRow row) {
  final requester = (row.master['requester'] ?? '').toString().trim();
  if (requester.isNotEmpty) return requester;
  return (row.master['created_by'] ?? '').toString().trim();
}

/// 이름 비교용 정규화 — 공백 차이("김경덕 " vs "김경덕")·연속 공백·대소문자 무시.
String _normalizeOwnerName(String raw) =>
    raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// 내 요청 판별.
///
/// DB(웹 포함)가 requester/created_by에 이름만 저장하므로 이름 기반 비교가
/// 한계지만, 정규화 후 requester·created_by 둘 다 확인해 누락을 줄인다.
bool issuanceIsOwnRequest(IssuanceRequestRow row, String? userName) {
  final me = _normalizeOwnerName(userName ?? '');
  if (me.isEmpty) return false;
  final requester =
      _normalizeOwnerName((row.master['requester'] ?? '').toString());
  final createdBy =
      _normalizeOwnerName((row.master['created_by'] ?? '').toString());
  return requester == me || createdBy == me;
}

List<IssuanceRequestRow> sortIssuanceRowsOwnFirst(
  List<IssuanceRequestRow> rows,
  String? userName,
) {
  final sorted = List<IssuanceRequestRow>.from(rows);
  sorted.sort((a, b) {
    final aOwn = issuanceIsOwnRequest(a, userName);
    final bOwn = issuanceIsOwnRequest(b, userName);
    if (aOwn != bOwn) return aOwn ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

({List<IssuanceRequestRow> mine, List<IssuanceRequestRow> others})
splitIssuanceRowsByOwner(
  List<IssuanceRequestRow> rows,
  String? userName,
) {
  final mine = <IssuanceRequestRow>[];
  final others = <IssuanceRequestRow>[];
  for (final row in sortIssuanceRowsOwnFirst(rows, userName)) {
    if (issuanceIsOwnRequest(row, userName)) {
      mine.add(row);
    } else {
      others.add(row);
    }
  }
  return (mine: mine, others: others);
}

class IssuanceRequestService {
  IssuanceRequestService({AppDependencies? deps}) : _deps = deps;

  final AppDependencies? _deps;

  SupabaseClient get _client => Supabase.instance.client;

  static bool isCancelledStatus(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'cancelled':
      case 'canceled':
      case 'cancel':
        return true;
      default:
        return normalized == '취소';
    }
  }

  Future<List<IssuanceRequestRow>> fetchRows(IssuanceDomain domain) async {
    return domain == IssuanceDomain.taxInvoice
        ? _fetchTaxInvoiceRequests()
        : _fetchPerformanceBondRequests();
  }

  /// 웹 `issuanceRequestBadgeCounts.ts` 와 동일한 발급요청 건수.
  Future<int> fetchRequestBadgeCount(IssuanceDomain domain) async {
    return domain == IssuanceDomain.taxInvoice
        ? _fetchTaxRequestBadgeCount()
        : _fetchBondRequestBadgeCount();
  }

  Future<int> _fetchTaxRequestBadgeCount() async {
    final invoicesRes = await _client
        .from('tax_invoices')
        .select('id, invoice_image_url, percentage, status')
        .eq('status', 'pending');
    final invoices = List<Map<String, dynamic>>.from(invoicesRes);
    if (invoices.isEmpty) return 0;

    final invoiceIds =
        invoices.map((e) => e['id']).where((id) => id != null).toList();
    final issuesRes = invoiceIds.isEmpty
        ? <dynamic>[]
        : await _client
              .from('tax_invoice_issues')
              .select('tax_invoice_id, invoice_image_url')
              .inFilter('tax_invoice_id', invoiceIds);
    final issuesByInvoice = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in List<Map<String, dynamic>>.from(issuesRes)) {
      final id = issue['tax_invoice_id'];
      issuesByInvoice.putIfAbsent(id, () => []);
      issuesByInvoice[id]!.add(issue);
    }

    var count = 0;
    for (final invoice in invoices) {
      final issues =
          issuesByInvoice[invoice['id']] ?? const <Map<String, dynamic>>[];
      final hasIssuedIssue = issues.any(
        (i) => _hasText(i['invoice_image_url']),
      );
      if (hasIssuedIssue) continue;

      final requestIssues =
          issues.where((i) => !_hasText(i['invoice_image_url'])).toList();
      if (requestIssues.isEmpty) {
        final pct = _toNum(invoice['percentage']);
        final masterIssued =
            _hasText(invoice['invoice_image_url']) && pct >= 100;
        if (!masterIssued) count += 1;
        continue;
      }
      count += requestIssues.length;
    }
    return count;
  }

  Future<int> _fetchBondRequestBadgeCount() async {
    final bondsRes = await _client
        .from('performance_bonds')
        .select('id, status, bond_image_url')
        .inFilter('status', ['pending', 'draft']);
    final bonds = List<Map<String, dynamic>>.from(bondsRes);
    if (bonds.isEmpty) return 0;

    final bondIds = bonds.map((b) => b['id']).where((id) => id != null).toList();
    if (bondIds.isEmpty) return 0;

    final issuesRes = await _client
        .from('performance_bond_issues')
        .select('performance_bond_id, bond_image_url')
        .inFilter('performance_bond_id', bondIds);
    final issues = List<Map<String, dynamic>>.from(issuesRes);
    final issuesByBond = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in issues) {
      final id = issue['performance_bond_id'];
      issuesByBond.putIfAbsent(id, () => []);
      issuesByBond[id]!.add(issue);
    }

    var count = 0;
    for (final bond in bonds) {
      final bondIssues = issuesByBond[bond['id']] ?? const [];
      final hasIssued =
          bondIssues.any((i) => _hasText(i['bond_image_url'])) ||
          _hasText(bond['bond_image_url']);
      if (hasIssued) continue;
      if (bondIssues.isEmpty) {
        count += 1;
      } else {
        count += bondIssues
            .where((i) => !_hasText(i['bond_image_url']))
            .length;
      }
    }
    return count;
  }

  double _toNum(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  Future<List<IssuanceRequestRow>> fetchCancelledRows(
    IssuanceDomain domain,
  ) async {
    return domain == IssuanceDomain.taxInvoice
        ? _fetchCancelledTaxInvoices()
        : _fetchCancelledPerformanceBonds();
  }

  Future<void> cancelMaster({
    required IssuanceDomain domain,
    required String masterId,
    required String cancelledBy,
    required String cancelReason,
  }) async {
    if (domain == IssuanceDomain.performanceBond) {
      await _cancelPerformanceBond(
        masterId: masterId,
        cancelledBy: cancelledBy,
        cancelReason: cancelReason,
      );
      return;
    }
    await _cancelViaSupabase(
      table: 'tax_invoices',
      masterId: masterId,
      cancelledBy: cancelledBy,
      cancelReason: cancelReason,
    );
  }

  /// 웹 `handleCancelBond` 와 동일 — RPC/API로 status를 cancelled로 저장한다.
  Future<void> _cancelPerformanceBond({
    required String masterId,
    required String cancelledBy,
    required String cancelReason,
  }) async {
    final reason = cancelReason.trim();
    final userName = cancelledBy.trim();

    try {
      await _client.rpc<void>(
        'cancel_performance_bond',
        params: {
          'p_bond_id': masterId,
          'p_user_name': userName,
          'p_cancel_reason': reason,
        },
      );
      return;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      final message = e.message;
      if (code == 'PGRST202' ||
          code == '42883' ||
          message.contains('cancel_performance_bond')) {
        // RPC 미배포 환경 — 아래 API/Supabase 폴백
      } else {
        throw Exception(_postgrestErrorMessage(e));
      }
    }

    final base = _deps?.effectiveBaseUrl.trim() ?? '';
    final payload = {
      'user_name': userName,
      'status': 'cancelled',
      'cancel_reason': reason,
      'cancelled_by': userName,
      'cancelled_at': DateTime.now().toIso8601String(),
    };

    if (base.isNotEmpty) {
      final res = await _deps!.transport.request(
        baseUrl: base,
        method: 'PATCH',
        path: '/api/performance-bonds/$masterId',
        jsonBody: payload,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      final message = _parseApiErrorMessage(res.body);
      throw Exception(
        message ?? '이행증권 취소에 실패했습니다. (${res.statusCode})',
      );
    }

    await _cancelViaSupabase(
      table: 'performance_bonds',
      masterId: masterId,
      cancelledBy: userName,
      cancelReason: reason,
    );
  }

  String _postgrestErrorMessage(PostgrestException error) {
    final message = error.message.trim();
    if (message.isNotEmpty &&
        message.toLowerCase() != 'bad request' &&
        !message.startsWith('{')) {
      return message;
    }
    final details = error.details?.toString().trim();
    if (details != null &&
        details.isNotEmpty &&
        details.toLowerCase() != 'bad request') {
      return details;
    }
    return '이행증권 취소에 실패했습니다.';
  }

  Future<void> _cancelViaSupabase({
    required String table,
    required String masterId,
    required String cancelledBy,
    required String cancelReason,
  }) async {
    final updated = await _client
        .from(table)
        .update({
          'status': 'cancelled',
          'cancel_reason': cancelReason.trim(),
          'cancelled_by': cancelledBy.trim(),
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', masterId)
        .select('id');
    if (updated.isEmpty) {
      throw Exception(
        table == 'performance_bonds'
            ? '취소 권한이 없습니다. BASE_URL 설정 후 다시 시도해 주세요.'
            : '취소에 실패했습니다. 권한을 확인해 주세요.',
      );
    }
  }

  String? _parseApiErrorMessage(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error']?.toString().trim();
        if (error != null && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return null;
  }

  Future<List<IssuanceRequestRow>> _fetchTaxInvoiceRequests() async {
    final invoicesRes = await _client
        .from('tax_invoices')
        .select('''
      id,
      created_at,
      status,
      percentage,
      invoice_image_url,
      invoice_number,
      customer_name,
      customer_registration_number,
      item_name,
      item_type,
      total_amount,
      supply_amount,
      tax_amount,
      issued_supply_amount,
      issued_tax_amount,
      issued_total_amount,
      mes_registered,
      issue_date,
      issue_request_date,
      branch,
      email,
      requester,
      created_by,
      business_registration_image_url,
      cancel_reason,
      cancelled_at,
      cancelled_by
    ''')
        .neq('status', 'cancelled');
    final invoices = List<Map<String, dynamic>>.from(invoicesRes);
    if (invoices.isEmpty) return [];

    final invoiceIds = invoices
        .map((e) => e['id'])
        .where((id) => id != null)
        .toList();
    final issuesRes = invoiceIds.isEmpty
        ? <dynamic>[]
        : await _client
              .from('tax_invoice_issues')
              .select('''
            id,
            tax_invoice_id,
            created_at,
            invoice_image_url,
            percentage,
            issue_order,
            is_urgent
          ''')
              .inFilter('tax_invoice_id', invoiceIds);
    final issues = List<Map<String, dynamic>>.from(issuesRes);

    final issuesByInvoiceId = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in issues) {
      final id = issue['tax_invoice_id'];
      issuesByInvoiceId.putIfAbsent(id, () => []);
      issuesByInvoiceId[id]!.add(issue);
    }

    final rows = <IssuanceRequestRow>[];
    for (final invoice in invoices) {
      if (isCancelledStatus((invoice['status'] ?? '').toString())) continue;

      final invoiceIssues =
          issuesByInvoiceId[invoice['id']] ?? const <Map<String, dynamic>>[];
      final issuedIssues = taxIssuedIssues(invoiceIssues);
      final pendingIssues = taxPendingIssues(invoiceIssues);
      final issuedPct = taxIssuedPct(invoiceIssues);
      final remainingPct = taxRemainingPct(invoiceIssues);
      final hasAnyIssued = taxHasAnyIssued(
        invoice: invoice,
        issues: invoiceIssues,
      );
      final fullyIssued = taxIsFullyIssued(
        invoice: invoice,
        issues: invoiceIssues,
      );
      final statusRaw = (invoice['status'] ?? '').toString().toLowerCase();

      // §5-1 발급요청: 웹(coad_home)과 동일하게 "실제 발급 이력 없음"일 때만 요청 목록에 포함.
      if (!hasAnyIssued) {
        if (pendingIssues.isNotEmpty) {
          for (final issue in pendingIssues) {
            rows.add(
              IssuanceRequestRow(
                master: invoice,
                issue: issue,
                domain: IssuanceDomain.taxInvoice,
                kind: IssuanceRowKind.request,
              ),
            );
          }
        } else if (statusRaw == 'pending') {
          rows.add(
            IssuanceRequestRow(
              master: invoice,
              issue: null,
              domain: IssuanceDomain.taxInvoice,
              kind: IssuanceRowKind.request,
            ),
          );
        }
      }

      // §5-2 부분발급: invoice 1행, 발급했으나 100% 미만
      if (hasAnyIssued && !fullyIssued) {
        final latestIssued = _latestIssue(issuedIssues);
        rows.add(
          IssuanceRequestRow(
            master: invoice,
            issue: latestIssued,
            domain: IssuanceDomain.taxInvoice,
            kind: IssuanceRowKind.partial,
            issuedPct: issuedPct,
            remainingPct: remainingPct,
          ),
        );
      }

      // §5-4 발급완료: 실제 발급 이력 1건 이상 (status 무관)
      if (hasAnyIssued) {
        final latestIssued = _latestIssue(issuedIssues);
        rows.add(
          IssuanceRequestRow(
            master: invoice,
            issue: latestIssued,
            domain: IssuanceDomain.taxInvoice,
            kind: IssuanceRowKind.issued,
            issuedPct: issuedPct,
            remainingPct: remainingPct,
          ),
        );
      }

      // §5-3 완료 100% (전체 탭·추후용)
      if (fullyIssued &&
          (statusRaw == 'completed' || statusRaw == 'complete')) {
        final latestIssued = _latestIssue(issuedIssues);
        rows.add(
          IssuanceRequestRow(
            master: invoice,
            issue: latestIssued,
            domain: IssuanceDomain.taxInvoice,
            kind: IssuanceRowKind.completed,
            issuedPct: issuedPct,
            remainingPct: remainingPct,
          ),
        );
      }
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<List<IssuanceRequestRow>> _fetchPerformanceBondRequests() async {
    final bondsRes = await _client
        .from('performance_bonds')
        .select('''
      id,
      created_at,
      status,
      bond_image_url,
      bond_number,
      bond_type,
      company_name,
      contract_amount,
      guarantee_rate,
      guarantee_period,
      contract_date,
      request_deadline,
      email,
      requester,
      created_by,
      cancel_reason,
      cancelled_at,
      cancelled_by
    ''')
        .neq('status', 'cancelled');
    final bonds = List<Map<String, dynamic>>.from(bondsRes);
    if (bonds.isEmpty) return [];

    final bondIds = bonds
        .map((e) => e['id'])
        .where((id) => id != null)
        .toList();
    final issuesRes = bondIds.isEmpty
        ? <dynamic>[]
        : await _client
              .from('performance_bond_issues')
              .select('''
            id,
            performance_bond_id,
            created_at,
            bond_image_url,
            request_image_url,
            construction_start_date,
            construction_end_date
          ''')
              .inFilter('performance_bond_id', bondIds);
    final issues = List<Map<String, dynamic>>.from(issuesRes);

    final issuesByBondId = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in issues) {
      final id = issue['performance_bond_id'];
      issuesByBondId.putIfAbsent(id, () => []);
      issuesByBondId[id]!.add(issue);
    }

    final rows = <IssuanceRequestRow>[];
    for (final bond in bonds) {
      if (isCancelledStatus((bond['status'] ?? '').toString())) continue;

      final bondIssues =
          issuesByBondId[bond['id']] ?? const <Map<String, dynamic>>[];
      final issuedIssues = bondIssues
          .where((e) => _hasText(e['bond_image_url']))
          .toList();
      final pendingIssues = bondIssues
          .where((e) => !_hasText(e['bond_image_url']))
          .toList();
      final hasAnyIssued =
          issuedIssues.isNotEmpty || _hasText(bond['bond_image_url']);
      final statusRaw = (bond['status'] ?? '').toString().toLowerCase();

      if (!hasAnyIssued && (statusRaw == 'pending' || statusRaw == 'draft')) {
        if (pendingIssues.isNotEmpty) {
          for (final issue in pendingIssues) {
            rows.add(
              IssuanceRequestRow(
                master: bond,
                issue: issue,
                domain: IssuanceDomain.performanceBond,
                kind: IssuanceRowKind.request,
              ),
            );
          }
        } else {
          rows.add(
            IssuanceRequestRow(
              master: bond,
              issue: null,
              domain: IssuanceDomain.performanceBond,
              kind: IssuanceRowKind.request,
            ),
          );
        }
      }

      if (hasAnyIssued) {
        final latestIssued = _latestIssue(issuedIssues);
        rows.add(
          IssuanceRequestRow(
            master: bond,
            issue: latestIssued,
            domain: IssuanceDomain.performanceBond,
            kind: IssuanceRowKind.issued,
          ),
        );
      }
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  /// [isCancelledStatus]와 동일한 취소 상태 값 (서버 필터용).
  static const _cancelledStatusValues = ['cancelled', 'canceled', 'cancel', '취소'];

  Future<List<IssuanceRequestRow>> _fetchCancelledTaxInvoices() async {
    final invoicesRes = await _client
        .from('tax_invoices')
        .select('''
      id,
      created_at,
      status,
      invoice_number,
      customer_name,
      item_name,
      item_type,
      total_amount,
      requester,
      created_by,
      cancel_reason,
      cancelled_at,
      cancelled_by
    ''')
        .inFilter('status', _cancelledStatusValues);
    final rows = <IssuanceRequestRow>[];
    for (final invoice in List<Map<String, dynamic>>.from(invoicesRes)) {
      rows.add(
        IssuanceRequestRow(
          master: invoice,
          issue: null,
          domain: IssuanceDomain.taxInvoice,
          kind: IssuanceRowKind.cancelled,
        ),
      );
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<List<IssuanceRequestRow>> _fetchCancelledPerformanceBonds() async {
    final bondsRes = await _client
        .from('performance_bonds')
        .select('''
      id,
      created_at,
      status,
      bond_type,
      bond_number,
      company_name,
      contract_amount,
      requester,
      created_by,
      cancel_reason,
      cancelled_at,
      cancelled_by
    ''')
        .inFilter('status', _cancelledStatusValues);
    final rows = <IssuanceRequestRow>[];
    for (final bond in List<Map<String, dynamic>>.from(bondsRes)) {
      rows.add(
        IssuanceRequestRow(
          master: bond,
          issue: null,
          domain: IssuanceDomain.performanceBond,
          kind: IssuanceRowKind.cancelled,
        ),
      );
    }
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Map<String, dynamic>? _latestIssue(List<Map<String, dynamic>> issuedIssues) {
    if (issuedIssues.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(issuedIssues)
      ..sort(
        (a, b) => _toDateTime(
          b['created_at'],
        ).compareTo(_toDateTime(a['created_at'])),
      );
    return sorted.first;
  }

  bool _hasText(dynamic value) => (value ?? '').toString().trim().isNotEmpty;

  DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse((value ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

int _rowKindPriority(IssuanceRowKind kind) {
  switch (kind) {
    case IssuanceRowKind.request:
      return 0;
    case IssuanceRowKind.partial:
      return 1;
    case IssuanceRowKind.issued:
      return 2;
    case IssuanceRowKind.completed:
      return 3;
    case IssuanceRowKind.cancelled:
      return 4;
  }
}

List<IssuanceRequestRow> _dedupeRowsForAllTab(List<IssuanceRequestRow> rows) {
  final best = <String, IssuanceRequestRow>{};
  for (final row in rows) {
    final id = row.master['id']?.toString();
    if (id == null || id.isEmpty) continue;
    final existing = best[id];
    if (existing == null ||
        _rowKindPriority(row.kind) < _rowKindPriority(existing.kind)) {
      best[id] = row;
    }
  }
  final merged = best.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return merged;
}

final issuanceRequestServiceProvider = Provider<IssuanceRequestService>((ref) {
  return IssuanceRequestService(deps: ref.watch(appDependenciesProvider));
});

final issuanceAllRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      return ref.read(issuanceRequestServiceProvider).fetchRows(domain);
    });

/// 발급요청 탭 — 미발급 issue 1건=1행 (웹 `request`).
final issuanceRequestRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return rows.where((row) => row.kind == IssuanceRowKind.request).toList();
    });

/// 내 발급대기 건 (정렬: 최신순).
final issuanceMyRequestRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final user = ref.watch(authControllerProvider);
      final rows = await ref.watch(issuanceRequestRowsProvider(domain).future);
      return rows
          .where((row) => issuanceIsOwnRequest(row, user?.name))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

/// 부분발급 탭 (웹 `partial`) — 추후 UI 확장용.
final issuancePartialRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return rows.where((row) => row.kind == IssuanceRowKind.partial).toList();
    });

/// 완료 탭 (웹 `completed`) — 100% 발급 + status completed (세금계산서).
final issuanceFullyCompletedRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      if (domain != IssuanceDomain.taxInvoice) return const [];
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return rows
          .where((row) => row.kind == IssuanceRowKind.completed)
          .toList();
    });

/// 발급완료 — 실제 발급 이력 1건 이상 (웹 `issued`, status·% 무관).
final issuanceCompletedRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return rows.where((row) => row.kind == IssuanceRowKind.issued).toList();
    });

/// 취소된 발급요청 건.
final issuanceCancelledRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      return ref
          .read(issuanceRequestServiceProvider)
          .fetchCancelledRows(domain);
    });

/// 전체 탭 — 마스터당 1행 (request > partial > issued > cancelled).
final issuanceAllTabRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      final cancelled = await ref.watch(
        issuanceCancelledRowsProvider(domain).future,
      );
      return _dedupeRowsForAllTab([...rows, ...cancelled]);
    });

/// false면 배지 API 미조회(앱 시작 부하 완화). 발급 탭·지연 후 true.
final issuanceBadgeLoadEnabledProvider = StateProvider<bool>((ref) => false);

/// 하단 탭 배지 — **내** 발급대기 건수 (본인 확인용).
final issuanceRequestBadgeCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authControllerProvider);
  if (user == null) return 0;
  final taxRows = await ref.watch(
    issuanceRequestRowsProvider(IssuanceDomain.taxInvoice).future,
  );
  final bondRows = await ref.watch(
    issuanceRequestRowsProvider(IssuanceDomain.performanceBond).future,
  );
  return [
    ...taxRows,
    ...bondRows,
  ].where((row) => issuanceIsOwnRequest(row, user.name)).length;
});

/// 허브 등 — 전체 발급대기 건수 (웹 배지 규칙).
final issuanceRequestTotalBadgeCountProvider = FutureProvider<int>((ref) async {
  final service = ref.read(issuanceRequestServiceProvider);
  final taxCount = await service.fetchRequestBadgeCount(
    IssuanceDomain.taxInvoice,
  );
  final bondCount = await service.fetchRequestBadgeCount(
    IssuanceDomain.performanceBond,
  );
  return taxCount + bondCount;
});

/// [issuanceBadgeLoadEnabledProvider]가 켜진 뒤에만 실제 건수를 조회.
final issuanceRequestBadgeCountVisibleProvider = Provider<AsyncValue<int>>((
  ref,
) {
  if (!ref.watch(issuanceBadgeLoadEnabledProvider)) {
    return const AsyncValue.data(0);
  }
  return ref.watch(issuanceRequestBadgeCountProvider);
});
