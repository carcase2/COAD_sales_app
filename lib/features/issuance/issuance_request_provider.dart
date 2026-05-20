import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum IssuanceDomain { taxInvoice, performanceBond }

typedef IssuanceLaunchTarget = ({IssuanceDomain domain, bool showCompleted});
final pendingIssuanceLaunchProvider = StateProvider<IssuanceLaunchTarget?>((ref) => null);

class IssuanceRequestRow {
  IssuanceRequestRow({
    required this.master,
    required this.issue,
    required this.domain,
    required this.isCompleted,
  });

  final Map<String, dynamic> master;
  final Map<String, dynamic>? issue;
  final IssuanceDomain domain;
  final bool isCompleted;

  DateTime get createdAt {
    final raw = issue?['created_at'] ?? master['created_at'];
    return DateTime.tryParse((raw ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get createdAtText {
    final dt = createdAt;
    if (dt.millisecondsSinceEpoch == 0) return '날짜 없음';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get title {
    if (domain == IssuanceDomain.taxInvoice) {
      return (master['customer_name'] ?? master['company_name'] ?? '세금계산서 요청').toString();
    }
    return (master['site_name'] ?? master['project_name'] ?? '이행증권 요청').toString();
  }

  String get subtitle {
    final requester = (master['created_by_name'] ?? master['created_by'] ?? '').toString();
    final status = _statusLabel((master['status'] ?? '').toString());
    final width = (master['width_mm'] ?? '').toString();
    final height = (master['height_mm'] ?? '').toString();
    final size = (width.isNotEmpty && height.isNotEmpty) ? ' · ${width}x$height' : '';
    return '상태: $status${requester.isNotEmpty ? ' · 담당: $requester' : ''}$size';
  }

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'pending':
        return '대기';
      case 'draft':
        return '임시저장';
      case 'in_progress':
      case 'inprogress':
        return '진행중';
      case 'completed':
      case 'complete':
        return '완료';
      default:
        return raw.isEmpty ? '-' : raw;
    }
  }
}

class IssuanceRequestService {
  SupabaseClient get _client => Supabase.instance.client;

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
      total_amount,
      branch,
      requester,
      created_by_name,
      created_by,
      width_mm,
      height_mm
    ''');
    final invoices = List<Map<String, dynamic>>.from(invoicesRes);
    if (invoices.isEmpty) return [];

    final invoiceIds = invoices.map((e) => e['id']).where((id) => id != null).toList();
    final issuesRes = invoiceIds.isEmpty
        ? <dynamic>[]
        : await _client.from('tax_invoice_issues').select('''
            id,
            tax_invoice_id,
            created_at,
            invoice_image_url,
            is_urgent
          ''').inFilter('tax_invoice_id', invoiceIds);
    final issues = List<Map<String, dynamic>>.from(issuesRes);

    final issuesByInvoiceId = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in issues) {
      final id = issue['tax_invoice_id'];
      issuesByInvoiceId.putIfAbsent(id, () => []);
      issuesByInvoiceId[id]!.add(issue);
    }

    final rows = <IssuanceRequestRow>[];
    for (final invoice in invoices) {
      final invoiceIssues = issuesByInvoiceId[invoice['id']] ?? const <Map<String, dynamic>>[];
      final hasIssuedIssue = invoiceIssues.any((e) => _hasText(e['invoice_image_url']));
      final issuedIssues = invoiceIssues.where((e) => _hasText(e['invoice_image_url'])).toList();

      final unissuedIssues = invoiceIssues.where((e) => !_hasText(e['invoice_image_url'])).toList();
      final percentage = _toNum(invoice['percentage']);
      final legacyCompleted = _hasText(invoice['invoice_image_url']) && percentage >= 100;
      final statusRaw = (invoice['status'] ?? '').toString().toLowerCase();
      final completedByStatus = statusRaw == 'completed' || statusRaw == 'complete';
      final isCompleted = hasIssuedIssue || legacyCompleted || completedByStatus;

      if (isCompleted) {
        issuedIssues.sort((a, b) => _toDateTime(b['created_at']).compareTo(_toDateTime(a['created_at'])));
        final latestIssued = issuedIssues.isNotEmpty ? issuedIssues.first : null;
        rows.add(
          IssuanceRequestRow(
            master: invoice,
            issue: latestIssued,
            domain: IssuanceDomain.taxInvoice,
            isCompleted: true,
          ),
        );
        continue;
      }

      if (unissuedIssues.isNotEmpty) {
        for (final issue in unissuedIssues) {
          rows.add(
            IssuanceRequestRow(
              master: invoice,
              issue: issue,
              domain: IssuanceDomain.taxInvoice,
              isCompleted: false,
            ),
          );
        }
        continue;
      }

      if ((invoice['status'] ?? '').toString() == 'pending') {
        rows.add(
          IssuanceRequestRow(
            master: invoice,
            issue: null,
            domain: IssuanceDomain.taxInvoice,
            isCompleted: false,
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
      company_name,
      site_name,
      project_name,
      bond_type,
      contract_amount,
      guarantee_rate,
      guarantee_period,
      requester,
      created_by_name,
      created_by,
      width_mm,
      height_mm
    ''');
    final bonds = List<Map<String, dynamic>>.from(bondsRes);
    if (bonds.isEmpty) return [];

    final bondIds = bonds.map((e) => e['id']).where((id) => id != null).toList();
    final issuesRes = bondIds.isEmpty
        ? <dynamic>[]
        : await _client.from('performance_bond_issues').select('''
            id,
            performance_bond_id,
            created_at,
            bond_image_url,
            is_urgent
          ''').inFilter('performance_bond_id', bondIds);
    final issues = List<Map<String, dynamic>>.from(issuesRes);

    final issuesByBondId = <dynamic, List<Map<String, dynamic>>>{};
    for (final issue in issues) {
      final id = issue['performance_bond_id'];
      issuesByBondId.putIfAbsent(id, () => []);
      issuesByBondId[id]!.add(issue);
    }

    final rows = <IssuanceRequestRow>[];
    for (final bond in bonds) {
      final bondIssues = issuesByBondId[bond['id']] ?? const <Map<String, dynamic>>[];
      final hasIssuedIssue = bondIssues.any((e) => _hasText(e['bond_image_url']));
      final issuedIssues = bondIssues.where((e) => _hasText(e['bond_image_url'])).toList();
      final issuedAtMaster = _hasText(bond['bond_image_url']);
      final statusRaw = (bond['status'] ?? '').toString().toLowerCase();
      final completedByStatus = statusRaw == 'completed' || statusRaw == 'complete';
      final isCompleted = hasIssuedIssue || issuedAtMaster || completedByStatus;

      final unissuedIssues = bondIssues.where((e) => !_hasText(e['bond_image_url'])).toList();
      if (isCompleted) {
        issuedIssues.sort((a, b) => _toDateTime(b['created_at']).compareTo(_toDateTime(a['created_at'])));
        final latestIssued = issuedIssues.isNotEmpty ? issuedIssues.first : null;
        rows.add(
          IssuanceRequestRow(
            master: bond,
            issue: latestIssued,
            domain: IssuanceDomain.performanceBond,
            isCompleted: true,
          ),
        );
        continue;
      }

      if (unissuedIssues.isEmpty) {
        rows.add(
          IssuanceRequestRow(
            master: bond,
            issue: null,
            domain: IssuanceDomain.performanceBond,
            isCompleted: false,
          ),
        );
      } else {
        for (final issue in unissuedIssues) {
          rows.add(
            IssuanceRequestRow(
              master: bond,
              issue: issue,
              domain: IssuanceDomain.performanceBond,
              isCompleted: false,
            ),
          );
        }
      }
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  bool _hasText(dynamic value) => (value ?? '').toString().trim().isNotEmpty;

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse((value ?? '').toString()) ?? 0;
  }

  DateTime _toDateTime(dynamic value) {
    return DateTime.tryParse((value ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

final issuanceRequestServiceProvider = Provider<IssuanceRequestService>((ref) {
  return IssuanceRequestService();
});

final issuanceAllRowsProvider = FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((ref, domain) async {
  return ref.read(issuanceRequestServiceProvider).fetchRows(domain);
});

final issuanceRequestRowsProvider = FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((ref, domain) async {
  final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
  return rows.where((row) => !row.isCompleted).toList();
});

final issuanceCompletedRowsProvider = FutureProvider.family<List<IssuanceRequestRow>, IssuanceDomain>((ref, domain) async {
  final rows = await ref.watch(issuanceAllRowsProvider(domain).future);
  return rows.where((row) => row.isCompleted).toList();
});

// 배지 기준 통일: 탭(all-scan 필터) 결과 개수 합계를 그대로 사용
final issuanceRequestBadgeCountProvider = FutureProvider<int>((ref) async {
  final taxRows = await ref.watch(issuanceRequestRowsProvider(IssuanceDomain.taxInvoice).future);
  final bondRows = await ref.watch(issuanceRequestRowsProvider(IssuanceDomain.performanceBond).future);
  return taxRows.length + bondRows.length;
});
