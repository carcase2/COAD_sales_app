import 'dart:typed_data';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/data/support_supabase.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kSupportAsQuotesBucket = 'support-as-quotes';

class SupportAsQuoteRepository {
  SupportAsQuoteRepository({SupabaseClient? client})
    : _client = client ?? supportSupabaseClient();

  final SupabaseClient _client;

  StorageFileApi get _pdfStorage =>
      _client.storage.from(kSupportAsQuotesBucket);

  Map<String, dynamic> _rowOf(SupportQuoteDocument doc) {
    final search = [
      doc.customerName,
      doc.phone,
      doc.email,
      doc.site,
      doc.address,
      doc.workName,
      doc.quoteNo,
      doc.note,
      doc.ymd,
      ...doc.lines.map((e) => '${e.name} ${e.spec} ${e.unit}'),
    ].join(' ');
    return {
      'id': doc.id,
      'quote_no': doc.quoteNo,
      'ymd': doc.ymd.trim().isEmpty ? null : doc.ymd.trim(),
      'customer_name': doc.customerName,
      'phone': doc.phone,
      'email': doc.email,
      'site': doc.site,
      'address': doc.address,
      'work_name': doc.workName,
      'lines': doc.lines.map((e) => e.toJson()).toList(),
      'note': doc.note,
      'total': doc.total,
      'nego_amount': doc.negoAmount,
      'nego_percent': doc.negoPercent,
      'sent_ymd': (doc.sentYmd ?? '').trim().isEmpty ? null : doc.sentYmd!.trim(),
      'call_log_id': (doc.callLogId ?? '').trim().isEmpty
          ? null
          : doc.callLogId!.trim(),
      'created_by': doc.createdBy ?? '',
      'created_at': doc.createdAt,
      'updated_by': doc.updatedBy ?? '',
      'updated_at': doc.updatedAt,
      'edit_history': doc.editHistory.map((e) => e.toJson()).toList(),
      'pdf_path': (doc.pdfPath ?? '').trim(),
      'pdf_uploaded_at': (doc.pdfUploadedAt ?? '').trim().isEmpty
          ? null
          : doc.pdfUploadedAt!.trim(),
      'pdf_uploaded_by': (doc.pdfUploadedBy ?? '').trim(),
      'search_text': search,
    };
  }

  String? publicPdfUrl(SupportQuoteDocument doc) {
    final path = (doc.pdfPath ?? '').trim();
    if (path.isEmpty) return null;
    return _pdfStorage.getPublicUrl(path);
  }

  static String pdfObjectPath(SupportQuoteDocument doc) {
    final no = doc.quoteNo.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final stem = no.isEmpty ? 'quote' : no;
    return '${doc.id}/$stem.pdf';
  }

  /// PDF를 클라우드에 올리고 생성일·작성자·수정자·발송일을 행에 함께 남긴다.
  Future<SupportQuoteDocument> uploadPdf(
    SupportQuoteDocument doc, {
    required Uint8List bytes,
    String? editorName,
    bool markSent = true,
  }) async {
    if (doc.id.trim().isEmpty) {
      throw ApiException('견적서를 먼저 저장한 뒤 PDF를 올려 주세요.');
    }
    try {
      final previous = await _findById(doc.id) ?? doc;
      final now = DateTime.now().toUtc().toIso8601String();
      final editor = (editorName ?? doc.updatedBy ?? doc.createdBy ?? '')
          .trim();
      final createdBy = (previous.createdBy ?? '').trim().isNotEmpty
          ? previous.createdBy!.trim()
          : (editor.isEmpty ? '미상' : editor);
      final createdAt = (previous.createdAt ?? '').trim().isNotEmpty
          ? previous.createdAt!
          : now;
      final sentYmd = markSent
          ? (((previous.sentYmd ?? doc.sentYmd) ?? '').trim().isNotEmpty
                ? (previous.sentYmd ?? doc.sentYmd)!.trim()
                : todayYmdSeoul())
          : previous.sentYmd;
      final path = pdfObjectPath(previous.copyWith(quoteNo: doc.quoteNo));
      await _pdfStorage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: 'application/pdf',
          metadata: {
            'created_at': createdAt,
            'created_by': createdBy,
            'updated_by': editor.isEmpty ? createdBy : editor,
            'sent_ymd': (sentYmd ?? '').trim(),
            'quote_no': doc.quoteNo.trim(),
            'customer_name': doc.customerName.trim(),
          },
        ),
      );
      final history = supportQuoteAppendEditHistory(
        previous: previous.editHistory,
        at: now,
        by: editor.isEmpty ? createdBy : editor,
        summary: markSent
            ? 'PDF 클라우드 저장 · 발송 ${(sentYmd ?? '').trim()}'
            : 'PDF 클라우드 저장',
      );
      final saved = previous.copyWith(
        quoteNo: doc.quoteNo.trim().isEmpty ? previous.quoteNo : doc.quoteNo,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedBy: editor.isEmpty ? createdBy : editor,
        updatedAt: now,
        sentYmd: sentYmd,
        pdfPath: path,
        pdfUploadedAt: now,
        pdfUploadedBy: editor.isEmpty ? createdBy : editor,
        editHistory: history,
      );
      await _client.from('support_as_quotes').upsert(_rowOf(saved));
      return saved;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('견적서 PDF를 클라우드에 올리지 못했습니다. $e');
    }
  }

  SupportQuoteDocument _fromRow(Map<String, dynamic> row) {
    return SupportQuoteDocument.fromJson({
      ...row,
      'lines': row['lines'],
      'edit_history': row['edit_history'],
    });
  }

  Future<SupportQuoteDocument?> _findById(String id) async {
    try {
      final res = await _client
          .from('support_as_quotes')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return _fromRow(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  Future<List<SupportQuoteDocument>> list({int limit = 400}) async {
    try {
      final res = await _client
          .from('support_as_quotes')
          .select()
          .order('ymd', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res)
          .map(_fromRow)
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      throw ApiException('A/S 견적서를 불러오지 못했습니다. $e');
    }
  }

  /// 접수별 발송완료일. 상담이 구두로 남아 있어도 견적서 발송을 반영할 때 쓴다.
  Future<Map<String, String>> sentYmdByCallLogIds(
    Iterable<String> callLogIds,
  ) async {
    final ids = callLogIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};
    try {
      final res = await _client
          .from('support_as_quotes')
          .select('call_log_id, sent_ymd')
          .inFilter('call_log_id', ids)
          .not('sent_ymd', 'is', null);
      final out = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final logId = (row['call_log_id'] ?? '').toString().trim();
        final sent = _sentYmdFromRow(row['sent_ymd']);
        if (logId.isEmpty || sent.isEmpty) continue;
        final prev = out[logId];
        if (prev == null || sent.compareTo(prev) > 0) out[logId] = sent;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  static String _sentYmdFromRow(Object? raw) {
    return (raw ?? '')
        .toString()
        .split('T')
        .first
        .split(' ')
        .first
        .trim();
  }

  /// [call_log_id]가 비어 있어도 전화·현장명으로 발송 견적을 접수에 연결한다.
  /// 상세 견적 목록은 현장 매칭을 쓰는데, 오늘 접수 리스트만 id로만 보면 구두로 남는다.
  Future<Map<String, String>> sentYmdForCallLogs(
    Iterable<({String id, String? phone, String? customerName})> logs,
  ) async {
    final items = [
      for (final e in logs)
        if (e.id.trim().isNotEmpty)
          (
            id: e.id.trim(),
            phone: (e.phone ?? '').trim(),
            customerName: (e.customerName ?? '').trim(),
          ),
    ];
    if (items.isEmpty) return const {};
    final byId = await sentYmdByCallLogIds(items.map((e) => e.id));
    final missing = items.where((e) => !byId.containsKey(e.id)).toList();
    if (missing.isEmpty) return byId;
    try {
      final res = await _client
          .from('support_as_quotes')
          .select('call_log_id, sent_ymd, phone, site, customer_name')
          .not('sent_ymd', 'is', null)
          .order('sent_ymd', ascending: false)
          .limit(800);
      final out = Map<String, String>.from(byId);
      final rows = List<Map<String, dynamic>>.from(res);
      for (final log in missing) {
        for (final row in rows) {
          final linked = (row['call_log_id'] ?? '').toString().trim();
          if (linked.isNotEmpty && linked != log.id) continue;
          final sent = _sentYmdFromRow(row['sent_ymd']);
          if (sent.isEmpty) continue;
          final matches = supportQuoteBelongsToSite(
            SupportQuoteDocument(
              id: '',
              ymd: '',
              customerName: (row['customer_name'] ?? '').toString(),
              phone: (row['phone'] ?? '').toString(),
              site: (row['site'] ?? '').toString(),
            ),
            phone: log.phone,
            site: log.customerName,
            customerName: log.customerName,
          );
          if (!matches) continue;
          out[log.id] = sent;
          break;
        }
      }
      return out;
    } catch (_) {
      return byId;
    }
  }

  Future<List<SupportQuoteDocument>> listForSite({
    String? phone,
    String? site,
    String? customerName,
    String? callLogId,
  }) async {
    final all = await list();
    return all
        .where((doc) {
          if ((callLogId ?? '').trim().isNotEmpty &&
              doc.callLogId == callLogId!.trim()) {
            return true;
          }
          return supportQuoteBelongsToSite(
            doc,
            phone: phone,
            site: site,
            customerName: customerName,
          );
        })
        .toList();
  }

  /// 접수 상세용 — 이 접수에 연결된 견적 + 주소가 같은 견적.
  Future<List<SupportQuoteDocument>> listForReception({
    required String callLogId,
    String? address,
  }) async {
    final all = await list();
    return all
        .where(
          (doc) => supportQuoteBelongsToReception(
            doc,
            callLogId: callLogId,
            address: address,
          ),
        )
        .toList();
  }

  @Deprecated('Use listForReception')
  Future<List<SupportQuoteDocument>> listForCallLog(String callLogId) =>
      listForReception(callLogId: callLogId);

  Future<String> nextQuoteNo({String? ymd}) async {
    final day = _quoteNoDayKey(ymd);
    final prefix = 'COAD$day-';
    try {
      final res = await _client
          .from('support_as_quotes')
          .select('quote_no')
          .like('quote_no', '$prefix%');
      var maxSeq = 0;
      for (final row in List<Map<String, dynamic>>.from(res)) {
        final no = (row['quote_no'] ?? '').toString();
        final seq = int.tryParse(no.replaceFirst(prefix, '')) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
      return '$prefix${(maxSeq + 1).toString().padLeft(3, '0')}';
    } catch (_) {
      final seq = (DateTime.now().millisecondsSinceEpoch % 1000)
          .toString()
          .padLeft(3, '0');
      return '$prefix$seq';
    }
  }

  /// `2026-09-05` / `20260905` → `20260905`
  static String _quoteNoDayKey(String? ymd) {
    final raw = (ymd ?? todayYmdSeoul()).trim();
    final compact = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (compact.length >= 8) return compact.substring(0, 8);
    return todayYmdSeoul().replaceAll('-', '');
  }

  Future<SupportQuoteDocument> upsert(
    SupportQuoteDocument doc, {
    String? editorName,
  }) async {
    if (doc.customerName.trim().isEmpty) {
      throw ApiException('고객명을 입력해 주세요.');
    }
    try {
      var quoteNo = doc.quoteNo.trim();
      if (quoteNo.isEmpty || quoteNo == '미리보기') {
        quoteNo = await nextQuoteNo(ymd: doc.ymd);
      }

      final previous = await _findById(doc.id);
      final now = DateTime.now().toUtc().toIso8601String();
      final editor = (editorName ?? doc.updatedBy ?? doc.createdBy ?? '')
          .trim();
      var quoteNoFixed = quoteNo;
      final withNo = doc.copyWith(quoteNo: quoteNoFixed);

      late final SupportQuoteDocument saved;
      if (previous == null) {
        final createdBy = (doc.createdBy ?? '').trim().isNotEmpty
            ? doc.createdBy!.trim()
            : editor;
        final createdAt = (doc.createdAt ?? '').trim().isNotEmpty
            ? doc.createdAt!
            : now;
        final history = supportQuoteAppendEditHistory(
          previous: doc.editHistory,
          at: now,
          by: editor,
          summary: '최초 작성 · ${supportQuoteSnapshotSummary(withNo)}',
        );
        saved = withNo.copyWith(
          createdBy: createdBy,
          createdAt: createdAt,
          updatedBy: editor.isEmpty ? createdBy : editor,
          updatedAt: now,
          editHistory: history,
        );
      } else {
        final createdBy = (previous.createdBy ?? '').trim().isNotEmpty
            ? previous.createdBy!.trim()
            : editor;
        final createdAt = (previous.createdAt ?? '').trim().isNotEmpty
            ? previous.createdAt!
            : (doc.createdAt ?? now);
        final history = supportQuoteAppendEditHistory(
          previous: previous.editHistory,
          at: now,
          by: editor,
          summary: supportQuoteEditDiffSummary(previous, withNo),
        );
        // 일반 저장 시 PDF 메타는 유지 (빈 값으로 덮어쓰지 않음)
        final keepPdfPath = (withNo.pdfPath ?? '').trim().isNotEmpty
            ? withNo.pdfPath
            : previous.pdfPath;
        final keepPdfAt = (withNo.pdfUploadedAt ?? '').trim().isNotEmpty
            ? withNo.pdfUploadedAt
            : previous.pdfUploadedAt;
        final keepPdfBy = (withNo.pdfUploadedBy ?? '').trim().isNotEmpty
            ? withNo.pdfUploadedBy
            : previous.pdfUploadedBy;
        saved = withNo.copyWith(
          createdBy: createdBy,
          createdAt: createdAt,
          updatedBy: editor.isEmpty ? createdBy : editor,
          updatedAt: now,
          editHistory: history,
          pdfPath: keepPdfPath,
          pdfUploadedAt: keepPdfAt,
          pdfUploadedBy: keepPdfBy,
        );
      }
      await _client.from('support_as_quotes').upsert(_rowOf(saved));
      return saved;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 견적서를 저장하지 못했습니다. $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('support_as_quotes').delete().eq('id', id);
    } catch (e) {
      throw ApiException('A/S 견적서를 삭제하지 못했습니다. $e');
    }
  }
}

bool supportQuotePhoneMatch(String a, String b) {
  final da = normalizePhoneDigits(a);
  final db = normalizePhoneDigits(b);
  if (da.length < 8 || db.length < 8) return false;
  return da.contains(db) || db.contains(da);
}
