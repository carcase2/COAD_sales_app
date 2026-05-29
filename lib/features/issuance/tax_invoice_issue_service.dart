import 'dart:io';
import 'dart:math';

import 'package:coad_customer_calls/features/issuance/tax_invoice_calc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TaxIssueSheetMode {
  /// 부분발급 탭 — 미발급 issue insert (이미지 없음)
  insertRequest,

  /// 발급요청 탭 — 미발급 issue update (이미지 첨부)
  fulfillRequest,

  /// 부분발급 탭 — 잔금 발급 (남은 %)
  remainderIssue,
}

class TaxInvoiceIssueService {
  TaxInvoiceIssueService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final _storage = Supabase.instance.client.storage.from('tax-invoices');
  final _rand = Random();

  String _todayYmd() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _safe(String input) =>
      input.trim().replaceAll(RegExp(r'[^a-zA-Z0-9가-힣._-]'), '_');

  Future<String> _uploadInvoiceImage({
    required PlatformFile file,
    required String customerName,
  }) async {
    final path = file.path;
    if (path == null) throw Exception('파일 경로가 없습니다.');
    final bytes = await File(path).readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('이미지 크기는 10MB 이하여야 합니다.');
    }
    final mime = lookupMimeType(path);
    if (mime == null || !mime.startsWith('image/')) {
      throw Exception('이미지 파일만 업로드할 수 있습니다.');
    }
    final date = _todayYmd();
    final safeOwner = _safe(customerName.isEmpty ? 'unknown' : customerName);
    final original = _safe(file.name);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final rand = _rand.nextInt(999999).toString().padLeft(6, '0');
    final objectPath = 'invoice/$safeOwner/$date/${stamp}_${rand}_$original';
    await _storage.uploadBinary(
      objectPath,
      bytes,
      fileOptions: FileOptions(upsert: false, contentType: mime),
    );
    return _storage.getPublicUrl(objectPath);
  }

  Future<Map<String, dynamic>> _loadInvoice(String invoiceId) async {
    final row = await _client
        .from('tax_invoices')
        .select('''
          id,
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
        .select('''
          id,
          tax_invoice_id,
          created_at,
          invoice_image_url,
          percentage,
          issue_order,
          is_urgent,
          issued_supply_amount,
          issued_tax_amount,
          issued_total_amount
        ''')
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

  String _resolveStatus({
    required double finalPct,
    required List<Map<String, dynamic>> allIssues,
  }) {
    final pending = taxPendingIssues(allIssues);
    if (finalPct >= 100 && pending.isEmpty) return 'completed';
    if (taxIssuedIssues(allIssues).isNotEmpty) return 'in_progress';
    return 'pending';
  }

  /// 부분발급 [발급요청] — insert only, `invoice_image_url=null`.
  Future<void> insertPartialRequestIssue({
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

    await _client.from('tax_invoice_issues').insert({
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
    });

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
  }

  /// 발급요청 [발급] 또는 부분발급 [잔금 발급].
  Future<void> completeIssue({
    required String invoiceId,
    required TaxIssueSheetMode mode,
    required PlatformFile imageFile,
    required String issuedBy,
    required String itemType,
    required String itemName,
    required double issuePercentage,
    String? targetIssueId,
    String? issueDate,
  }) async {
    final invoice = await _loadInvoice(invoiceId);
    final issues = await _loadIssues(invoiceId);
    final pending = taxPendingIssues(issues);
    final totalIssuedPct = taxIssuedPct(issues);

    final customerName = (invoice['customer_name'] ?? '').toString();
    final imageUrl = await _uploadInvoiceImage(
      file: imageFile,
      customerName: customerName,
    );

    double issuePctForRecord;
    double finalPct;

    if (mode == TaxIssueSheetMode.fulfillRequest) {
      Map<String, dynamic>? target;
      if (targetIssueId != null) {
        for (final i in pending) {
          if (i['id']?.toString() == targetIssueId) {
            target = i;
            break;
          }
        }
      }
      target ??= pending.isNotEmpty ? pending.first : null;
      if (target == null) {
        throw Exception('발급할 발급요청 건을 찾을 수 없습니다.');
      }
      issuePctForRecord = _num(target['percentage']).toDouble();
      if (issuePctForRecord <= 0) issuePctForRecord = issuePercentage;
      finalPct = totalIssuedPct + issuePctForRecord;
    } else {
      issuePctForRecord = issuePercentage;
      finalPct = totalIssuedPct + issuePercentage;
    }

    final amounts = _amountsForPct(invoice, issuePctForRecord);
    final existingIssuedSupply = _num(invoice['issued_supply_amount']).round();
    final existingIssuedTax = _num(invoice['issued_tax_amount']).round();
    final existingIssuedTotal = _num(invoice['issued_total_amount']).round();

    final totalSupply = existingIssuedSupply + amounts.supply;
    final totalTax = existingIssuedTax + amounts.tax;
    final totalTotal = existingIssuedTotal + amounts.total;

    final issueUpdate = {
      'issue_date': issueDate ?? _todayYmd(),
      'issued_by': issuedBy,
      'issued_supply_amount': amounts.supply,
      'issued_tax_amount': amounts.tax,
      'issued_total_amount': amounts.total,
      'invoice_image_url': imageUrl,
      'item_type': itemType,
      'item_name': itemName.trim(),
    };

    String? updatedIssueId;
    if (mode == TaxIssueSheetMode.fulfillRequest) {
      final targetId =
          targetIssueId ??
          (pending.isNotEmpty ? pending.first['id'] : null)?.toString();
      if (targetId == null) {
        throw Exception('발급할 발급요청 ID가 없습니다.');
      }
      await _client
          .from('tax_invoice_issues')
          .update(issueUpdate)
          .eq('id', targetId);
      updatedIssueId = targetId;
    } else {
      final inserted = await _client
          .from('tax_invoice_issues')
          .insert({
            'tax_invoice_id': invoiceId,
            'percentage': issuePctForRecord,
            'issue_order': _nextIssueOrder(issues),
            'is_urgent': false,
            ...issueUpdate,
          })
          .select('id')
          .single();
      updatedIssueId = inserted['id']?.toString();
    }

    final refreshed = await _loadIssues(invoiceId);
    final status = _resolveStatus(finalPct: finalPct, allIssues: refreshed);

    await _client
        .from('tax_invoices')
        .update({
          'status': status,
          'invoice_image_url': imageUrl,
          'issue_request_date': issueDate ?? _todayYmd(),
          'issued_by': issuedBy,
          'percentage': finalPct,
          'issued_supply_amount': totalSupply,
          'issued_tax_amount': totalTax,
          'issued_total_amount': totalTotal,
          'item_type': itemType,
          'item_name': itemName.trim(),
        })
        .eq('id', invoiceId);

    if (updatedIssueId == null) {
      throw Exception('발급 이력 저장에 실패했습니다.');
    }
  }
}
