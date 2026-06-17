import 'package:supabase_flutter/supabase_flutter.dart';

enum TaxIssueSheetMode {
  /// 부분발급 탭 — 미발급 issue insert (이미지 없음)
  insertRequest,
}

class TaxInvoiceIssueService {
  TaxInvoiceIssueService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String _todayYmd() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, dynamic>> _loadInvoice(String invoiceId) async {
    final row = await _client
        .from('tax_invoices')
        .select('''
          id,
          status,
          percentage,
          supply_amount,
          tax_amount,
          total_amount,
          issued_supply_amount,
          issued_tax_amount,
          issued_total_amount
        ''')
        .eq('id', invoiceId)
        .maybeSingle();
    if (row == null) throw Exception('세금계산서를 찾을 수 없습니다.');
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> _loadIssues(String invoiceId) async {
    final res = await _client
        .from('tax_invoice_issues')
        .select('id, issue_order')
        .eq('tax_invoice_id', invoiceId)
        .order('issue_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  int _nextIssueOrder(List<Map<String, dynamic>> issues) {
    if (issues.isEmpty) return 1;
    var max = 0;
    for (final i in issues) {
      final o = (i['issue_order'] as num?)?.toInt() ?? 0;
      if (o > max) max = o;
    }
    return max + 1;
  }

  num _num(dynamic v) {
    if (v is num) return v;
    return num.tryParse((v ?? '').toString()) ?? 0;
  }

  ({int supply, int tax, int total}) _amountsForPct(
    Map<String, dynamic> invoice,
    double pct,
  ) {
    final ratio = pct / 100;
    return (
      supply: (_num(invoice['supply_amount']) * ratio).round(),
      tax: (_num(invoice['tax_amount']) * ratio).round(),
      total: (_num(invoice['total_amount']) * ratio).round(),
    );
  }

  /// 부분발급 [발급요청] — insert only, `invoice_image_url=null`.
  Future<String> insertPartialRequestIssue({
    required String invoiceId,
    required double issuePercentage,
    required String issuedBy,
    required String itemType,
    required String itemName,
    String? issueDate,
  }) async {
    final invoice = await _loadInvoice(invoiceId);
    final issues = await _loadIssues(invoiceId);
    final amounts = _amountsForPct(invoice, issuePercentage);
    final existingIssuedSupply = _num(invoice['issued_supply_amount']).round();
    final existingIssuedTax = _num(invoice['issued_tax_amount']).round();
    final existingIssuedTotal = _num(invoice['issued_total_amount']).round();

    final inserted = await _client
        .from('tax_invoice_issues')
        .insert({
          'tax_invoice_id': invoiceId,
          'issue_date': issueDate ?? _todayYmd(),
          'issued_by': issuedBy,
          'percentage': issuePercentage,
          'issued_supply_amount': amounts.supply,
          'issued_tax_amount': amounts.tax,
          'issued_total_amount': amounts.total,
          'invoice_image_url': null,
          'issue_order': _nextIssueOrder(issues),
          'is_urgent': false,
          'item_type': itemType,
          'item_name': itemName.trim(),
        })
        .select('id')
        .single();

    final currentPct = _num(invoice['percentage']);
    await _client
        .from('tax_invoices')
        .update({
          'status': 'pending',
          'percentage': currentPct + issuePercentage,
          'issued_supply_amount': existingIssuedSupply + amounts.supply,
          'issued_tax_amount': existingIssuedTax + amounts.tax,
          'issued_total_amount': existingIssuedTotal + amounts.total,
        })
        .eq('id', invoiceId);

    return inserted['id'].toString();
  }
}
