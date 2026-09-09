import 'dart:math';
import 'dart:typed_data';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kSizeQuotesBucket = 'standard-unit-price-quotes';
const kSizeQuotePromoBucket = 'standard-unit-price-promo';

class SizeQuoteRepository {
  SizeQuoteRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  StorageFileApi get _pdfStorage => _client.storage.from(kSizeQuotesBucket);
  StorageFileApi get _promoStorage =>
      _client.storage.from(kSizeQuotePromoBucket);

  Map<String, dynamic> _rowOf(SizeQuoteDocument doc) {
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
      doc.modelName,
      doc.categoryName,
      doc.sizeLabel,
      doc.createdBy ?? '',
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
      'category_id': (doc.categoryId ?? '').trim().isEmpty
          ? null
          : doc.categoryId!.trim(),
      'category_name': doc.categoryName,
      'model_id': (doc.modelId ?? '').trim().isEmpty
          ? null
          : doc.modelId!.trim(),
      'model_name': doc.modelName,
      'width_mm': doc.widthMm,
      'height_mm': doc.heightMm,
      'quantity': doc.quantity,
      'standard_price': doc.standardPrice,
      'markup_type': normalizeSizeQuoteMarkup(doc.markupType),
      'markup_value': doc.markupValue,
      'lines': doc.lines.map((e) => e.toJson()).toList(),
      'promo_image_ids': doc.promoImageIds,
      'note': doc.note,
      'total': doc.total,
      'nego_amount': doc.negoAmount,
      'nego_percent': doc.negoPercent,
      'target_total': doc.targetTotal,
      'sent_ymd': (doc.sentYmd ?? '').trim().isEmpty
          ? null
          : doc.sentYmd!.trim(),
      'email_sent_ymd': (doc.emailSentYmd ?? '').trim().isEmpty
          ? null
          : doc.emailSentYmd!.trim(),
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

  SizeQuoteDocument _fromRow(Map<String, dynamic> row) {
    return SizeQuoteDocument.fromJson({
      ...row,
      'lines': row['lines'],
      'edit_history': row['edit_history'],
      'promo_image_ids': row['promo_image_ids'],
    });
  }

  String? publicPdfUrl(SizeQuoteDocument doc) {
    final path = (doc.pdfPath ?? '').trim();
    if (path.isEmpty) return null;
    return _pdfStorage.getPublicUrl(path);
  }

  String publicPromoUrl(String storagePath) {
    return _promoStorage.getPublicUrl(storagePath);
  }

  static String pdfObjectPath(SizeQuoteDocument doc) {
    final no = doc.quoteNo.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final stem = no.isEmpty ? 'quote' : no;
    return '${doc.id}/$stem.pdf';
  }

  static String newId([String prefix = 'suq']) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${prefix}_$now$rand';
  }

  Future<SizeQuoteDocument?> _findById(String id) async {
    try {
      final res = await _client
          .from('standard_unit_price_quotes')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return _fromRow(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  Future<List<SizeQuoteDocument>> list({int limit = 400}) async {
    try {
      final res = await _client
          .from('standard_unit_price_quotes')
          .select()
          .order('ymd', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(res)
          .map(_fromRow)
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (e) {
      throw ApiException('표준단가 견적서를 불러오지 못했습니다. $e');
    }
  }

  Future<List<SizeQuoteDocument>> listSimilar({
    required String modelId,
    required int widthMm,
    required int heightMm,
    String? excludeId,
    int toleranceMm = 500,
    int limit = 30,
  }) async {
    final id = modelId.trim();
    if (id.isEmpty || widthMm <= 0 || heightMm <= 0) return const [];
    try {
      var query = _client
          .from('standard_unit_price_quotes')
          .select()
          .eq('model_id', id)
          .gte('width_mm', widthMm - toleranceMm)
          .lte('width_mm', widthMm + toleranceMm)
          .gte('height_mm', heightMm - toleranceMm)
          .lte('height_mm', heightMm + toleranceMm);
      if ((excludeId ?? '').trim().isNotEmpty) {
        query = query.neq('id', excludeId!.trim());
      }
      final res = await query
          .order('ymd', ascending: false)
          .limit(limit);
      final rows = List<Map<String, dynamic>>.from(res)
          .map(_fromRow)
          .where((e) => e.id.isNotEmpty)
          .toList();
      return sizeQuoteSimilarOf(
        all: rows,
        modelId: id,
        widthMm: widthMm,
        heightMm: heightMm,
        excludeId: excludeId,
        toleranceMm: toleranceMm,
        limit: limit,
      );
    } catch (e) {
      throw ApiException('비슷한 사이즈 견적을 불러오지 못했습니다. $e');
    }
  }

  Future<String> nextQuoteNo({String? ymd}) async {
    final day = _quoteNoDayKey(ymd);
    final prefix = 'STD$day-';
    try {
      final res = await _client
          .from('standard_unit_price_quotes')
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

  static String _quoteNoDayKey(String? ymd) {
    final raw = (ymd ?? todayYmdSeoul()).trim();
    final compact = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (compact.length >= 8) return compact.substring(0, 8);
    return todayYmdSeoul().replaceAll('-', '');
  }

  Future<SizeQuoteDocument> upsert(
    SizeQuoteDocument doc, {
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
      final withNo = doc.copyWith(quoteNo: quoteNo);

      late final SizeQuoteDocument saved;
      if (previous == null) {
        final createdBy = (doc.createdBy ?? '').trim().isNotEmpty
            ? doc.createdBy!.trim()
            : editor;
        final createdAt = (doc.createdAt ?? '').trim().isNotEmpty
            ? doc.createdAt!
            : now;
        saved = withNo.copyWith(
          createdBy: createdBy,
          createdAt: createdAt,
          updatedBy: editor.isEmpty ? createdBy : editor,
          updatedAt: now,
          editHistory: sizeQuoteAppendEditHistory(
            previous: doc.editHistory,
            at: now,
            by: editor,
            summary: '최초 작성 · ${sizeQuoteSnapshotSummary(withNo)}',
          ),
        );
      } else {
        final createdBy = (previous.createdBy ?? '').trim().isNotEmpty
            ? previous.createdBy!.trim()
            : editor;
        final createdAt = (previous.createdAt ?? '').trim().isNotEmpty
            ? previous.createdAt!
            : (doc.createdAt ?? now);
        saved = withNo.copyWith(
          createdBy: createdBy,
          createdAt: createdAt,
          updatedBy: editor.isEmpty ? createdBy : editor,
          updatedAt: now,
          editHistory: sizeQuoteAppendEditHistory(
            previous: previous.editHistory,
            at: now,
            by: editor,
            summary: sizeQuoteEditDiffSummary(previous, withNo),
          ),
          pdfPath: (withNo.pdfPath ?? '').trim().isNotEmpty
              ? withNo.pdfPath
              : previous.pdfPath,
          pdfUploadedAt: (withNo.pdfUploadedAt ?? '').trim().isNotEmpty
              ? withNo.pdfUploadedAt
              : previous.pdfUploadedAt,
          pdfUploadedBy: (withNo.pdfUploadedBy ?? '').trim().isNotEmpty
              ? withNo.pdfUploadedBy
              : previous.pdfUploadedBy,
        );
      }
      await _client.from('standard_unit_price_quotes').upsert(_rowOf(saved));
      return saved;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('표준단가 견적서를 저장하지 못했습니다. $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('standard_unit_price_quotes').delete().eq('id', id);
    } catch (e) {
      throw ApiException('표준단가 견적서를 삭제하지 못했습니다. $e');
    }
  }

  Future<SizeQuoteDocument> uploadPdf(
    SizeQuoteDocument doc, {
    required Uint8List bytes,
    String? editorName,
    bool markSent = true,
    bool markEmail = false,
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
      final emailSentYmd = markEmail
          ? (((previous.emailSentYmd ?? doc.emailSentYmd) ?? '')
                    .trim()
                    .isNotEmpty
                ? (previous.emailSentYmd ?? doc.emailSentYmd)!.trim()
                : todayYmdSeoul())
          : previous.emailSentYmd;
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
            'email_sent_ymd': (emailSentYmd ?? '').trim(),
            'quote_no': doc.quoteNo.trim(),
            'site': doc.site.trim(),
          },
        ),
      );
      final summary = [
        'PDF 클라우드 저장',
        if (markEmail) '메일 ${(emailSentYmd ?? '').trim()}',
        if (markSent && !markEmail) '발송 ${(sentYmd ?? '').trim()}',
      ].join(' · ');
      final saved = previous.copyWith(
        quoteNo: doc.quoteNo.trim().isEmpty ? previous.quoteNo : doc.quoteNo,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedBy: editor.isEmpty ? createdBy : editor,
        updatedAt: now,
        sentYmd: sentYmd,
        emailSentYmd: emailSentYmd,
        pdfPath: path,
        pdfUploadedAt: now,
        pdfUploadedBy: editor.isEmpty ? createdBy : editor,
        editHistory: sizeQuoteAppendEditHistory(
          previous: previous.editHistory,
          at: now,
          by: editor.isEmpty ? createdBy : editor,
          summary: summary,
        ),
      );
      await _client.from('standard_unit_price_quotes').upsert(_rowOf(saved));
      return saved;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('견적서 PDF를 클라우드에 올리지 못했습니다. $e');
    }
  }

  Future<List<SizeQuotePromoImage>> listPromoImages(String modelId) async {
    final id = modelId.trim();
    if (id.isEmpty) return const [];
    try {
      final res = await _client
          .from('standard_unit_price_promo_images')
          .select()
          .eq('model_id', id)
          .order('sort_order')
          .order('created_at');
      return List<Map<String, dynamic>>.from(res)
          .map(SizeQuotePromoImage.fromJson)
          .where((e) => e.id.isNotEmpty && e.storagePath.isNotEmpty)
          .toList();
    } catch (e) {
      throw ApiException('홍보 이미지를 불러오지 못했습니다. $e');
    }
  }

  Future<List<SizeQuotePromoImage>> listPromoImagesByIds(
    Iterable<String> ids,
  ) async {
    final list = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return const [];
    try {
      final res = await _client
          .from('standard_unit_price_promo_images')
          .select()
          .inFilter('id', list);
      final byId = {
        for (final row in List<Map<String, dynamic>>.from(res))
          '${row['id']}': SizeQuotePromoImage.fromJson(row),
      };
      return [
        for (final id in list)
          if (byId[id] != null) byId[id]!,
      ];
    } catch (e) {
      throw ApiException('홍보 이미지를 불러오지 못했습니다. $e');
    }
  }

  Future<SizeQuotePromoImage> uploadPromoImage({
    required String modelId,
    required Uint8List bytes,
    required String fileName,
    String title = '',
    String? createdBy,
  }) async {
    final id = newId('supi');
    final ext = _imageExt(fileName);
    final path = '$modelId/$id.$ext';
    try {
      await _promoStorage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _imageContentType(ext),
        ),
      );
      final row = {
        'id': id,
        'model_id': modelId,
        'title': title.trim(),
        'storage_path': path,
        'sort_order': DateTime.now().millisecondsSinceEpoch,
        'created_by': createdBy ?? '',
      };
      await _client.from('standard_unit_price_promo_images').insert(row);
      return SizeQuotePromoImage.fromJson(row);
    } catch (e) {
      throw ApiException('홍보 이미지를 올리지 못했습니다. $e');
    }
  }

  Future<SizeQuotePromoImage> replacePromoImage({
    required SizeQuotePromoImage image,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = _imageExt(fileName);
    final path =
        '${image.modelId}/${image.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await _promoStorage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _imageContentType(ext),
        ),
      );
      final old = image.storagePath.trim();
      if (old.isNotEmpty && old != path) {
        try {
          await _promoStorage.remove([old]);
        } catch (_) {}
      }
      await _client
          .from('standard_unit_price_promo_images')
          .update({'storage_path': path})
          .eq('id', image.id);
      return image.copyWith(storagePath: path);
    } catch (e) {
      throw ApiException('홍보 이미지를 바꾸지 못했습니다. $e');
    }
  }

  Future<void> updatePromoImage({
    required String id,
    String? title,
    int? sortOrder,
  }) async {
    final patch = <String, dynamic>{};
    if (title != null) patch['title'] = title.trim();
    if (sortOrder != null) patch['sort_order'] = sortOrder;
    if (patch.isEmpty) return;
    try {
      await _client
          .from('standard_unit_price_promo_images')
          .update(patch)
          .eq('id', id);
    } catch (e) {
      throw ApiException('홍보 이미지를 수정하지 못했습니다. $e');
    }
  }

  Future<void> deletePromoImage(SizeQuotePromoImage image) async {
    try {
      if (image.storagePath.trim().isNotEmpty) {
        await _promoStorage.remove([image.storagePath]);
      }
      await _client
          .from('standard_unit_price_promo_images')
          .delete()
          .eq('id', image.id);
    } catch (e) {
      throw ApiException('홍보 이미지를 삭제하지 못했습니다. $e');
    }
  }

  Future<Uint8List> downloadPromoBytes(String storagePath) async {
    try {
      return await _promoStorage.download(storagePath);
    } catch (e) {
      throw ApiException('홍보 이미지를 받지 못했습니다. $e');
    }
  }

  static String _imageExt(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

final sizeQuoteRepositoryProvider = Provider<SizeQuoteRepository>((ref) {
  return SizeQuoteRepository();
});
