import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportAsQuoteRepository {
  SupportAsQuoteRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      'sent_ymd': (doc.sentYmd ?? '').trim().isEmpty ? null : doc.sentYmd!.trim(),
      'call_log_id': (doc.callLogId ?? '').trim().isEmpty
          ? null
          : doc.callLogId!.trim(),
      'created_by': doc.createdBy ?? '',
      'created_at': doc.createdAt,
      'search_text': search,
    };
  }

  SupportQuoteDocument _fromRow(Map<String, dynamic> row) {
    return SupportQuoteDocument.fromJson({
      ...row,
      'lines': row['lines'],
    });
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

  Future<String> nextQuoteNo({String? year}) async {
    final y = year ?? todayYmdSeoul().substring(0, 4);
    final prefix = 'COAD$y-';
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

  Future<SupportQuoteDocument> upsert(SupportQuoteDocument doc) async {
    if (doc.customerName.trim().isEmpty) {
      throw ApiException('고객명을 입력해 주세요.');
    }
    try {
      var quoteNo = doc.quoteNo.trim();
      if (quoteNo.isEmpty) {
        quoteNo = await nextQuoteNo(year: doc.ymd.trim().length >= 4
            ? doc.ymd.substring(0, 4)
            : null);
      }
      final saved = doc.copyWith(quoteNo: quoteNo);
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
