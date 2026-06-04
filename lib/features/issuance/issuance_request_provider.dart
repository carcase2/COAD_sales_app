import 'package:coad_customer_calls/features/issuance/tax_invoice_calc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum IssuanceDomain { taxInvoice, performanceBond }

/// 웹 `IssuanceInnerTab` 과 대응 (Flutter 메인 UI는 request / all / issued 만 사용).
enum IssuanceRowKind { request, partial, completed, issued }

typedef IssuanceLaunchTarget = ({IssuanceDomain domain, bool showCompleted});
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

class IssuanceRequestService {
  SupabaseClient get _client => Supabase.instance.client;

  static bool isCancelledStatus(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'cancelled':
      case 'canceled':
      case 'cancel':
        return true;
      default:
        return false;
    }
  }

  Future<List<IssuanceRequestRow>> fetchRows(IssuanceDomain domain) async {
    return domain == IssuanceDomain.taxInvoice
        ? _fetchTaxInvoiceRequests()
        : _fetchPerformanceBondRequests();
  }

  Future<List<IssuanceRequestRow>> _fetchTaxInvoiceRequests() async {
    final invoicesRes = await _client.from('tax_invoices').select('''
      id,
      created_at,
      status,
      percentage,
      invoice_image_url,
      customer_name,
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
      requester,
      created_by
    ''');
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

      // §5-1 발급요청: 미발급 issue 1건=1행, 발급 이력 있으면 제외
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
    final bondsRes = await _client.from('performance_bonds').select('''
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
      requester,
      created_by
    ''');
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
            bond_image_url
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

      if (!hasAnyIssued) {
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
        } else if (statusRaw == 'pending' || statusRaw == 'draft') {
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
  return IssuanceRequestService();
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

/// 부분발급 탭 (웹 `partial`) — 추후 UI 확장용.
final issuancePartialRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return rows.where((row) => row.kind == IssuanceRowKind.partial).toList();
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

/// 전체 탭 — invoice당 1행 (request > partial > issued 우선).
final issuanceAllTabRowsProvider =
    FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((
      ref,
      domain,
    ) async {
      final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
      return _dedupeRowsForAllTab(
        rows.where((row) => !row.isCancelled).toList(),
      );
    });

/// false면 배지 API 미조회(앱 시작 부하 완화). 발급 탭·지연 후 true.
final issuanceBadgeLoadEnabledProvider = StateProvider<bool>((ref) => false);

final issuanceRequestBadgeCountProvider = FutureProvider<int>((ref) async {
  final taxRows = await ref.watch(
    issuanceRequestRowsProvider(IssuanceDomain.taxInvoice).future,
  );
  final bondRows = await ref.watch(
    issuanceRequestRowsProvider(IssuanceDomain.performanceBond).future,
  );
  return taxRows.length + bondRows.length;
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
