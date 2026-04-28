import 'dart:convert';
import 'dart:io';

import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/models/estimate_document.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EstimateDocumentRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<EstimateDocument>> list({String? query}) async {
    try {
      final q = query?.trim() ?? '';
      PostgrestFilterBuilder<List<Map<String, dynamic>>> request = _client
          .from('estimate_documents')
          .select();
      if (q.isNotEmpty) {
        final like = '%$q%';
        request = request.or(
          'category.ilike.$like,model_name.ilike.$like,customer_name.ilike.$like,site_name.ilike.$like,memo.ilike.$like,search_text.ilike.$like',
        );
      }
      final rows = await request.order('updated_at', ascending: false);
      final docs = rows.map(_fromRemoteRow).toList();
      await _saveLocalBatch(docs);
      return docs;
    } catch (_) {
      // 네트워크/테이블 오류 시 로컬 캐시로 fallback
      return _listLocal(query: query);
    }
  }

  Future<List<EstimateDocument>> _listLocal({String? query}) async {
    final db = await DatabaseHelper.instance.database;
    final q = query?.trim() ?? '';
    final rows = await db.query(
      'estimate_documents',
      where: q.isEmpty ? null : 'search_text LIKE ?',
      whereArgs: q.isEmpty ? null : ['%${q.toLowerCase()}%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((row) {
      final raw = (row['data'] ?? '{}').toString();
      return EstimateDocument.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }).toList();
  }

  Future<void> upsert(EstimateDocument doc) async {
    await _upsertLocal(doc);
    try {
      await _client.from('estimate_documents').upsert({
        'id': doc.id,
        'category': doc.category,
        'model_name': doc.modelName,
        'customer_name': doc.customerName,
        'site_name': doc.siteName,
        'base_amount': doc.baseAmount,
        'extra_items': doc.extraItems.map((e) => e.toJson()).toList(),
        'custom_fields': doc.customFields,
        'memo': doc.memo,
        'search_text': _buildSearchText(doc),
        'created_at': doc.createdAt.toIso8601String(),
        'updated_at': doc.updatedAt.toIso8601String(),
      });
    } on SocketException {
      // 오프라인에서는 로컬 저장만 유지
    } catch (_) {
      // 서버 오류는 화면 동작을 막지 않는다.
    }
  }

  Future<void> _upsertLocal(EstimateDocument doc) async {
    final db = await DatabaseHelper.instance.database;
    final searchText = _buildSearchText(doc);
    await db.insert('estimate_documents', {
      'id': doc.id,
      'category': doc.category,
      'model_name': doc.modelName,
      'customer_name': doc.customerName,
      'site_name': doc.siteName,
      'search_text': searchText,
      'data': jsonEncode(doc.toJson()),
      'created_at': doc.createdAt.toIso8601String(),
      'updated_at': doc.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('estimate_documents', where: 'id = ?', whereArgs: [id]);
    try {
      await _client.from('estimate_documents').delete().eq('id', id);
    } catch (_) {
      // 서버 삭제 실패 시 로컬 우선 동작
    }
  }

  String _buildSearchText(EstimateDocument doc) {
    return [
      doc.category,
      doc.modelName,
      doc.customerName,
      doc.siteName,
      doc.memo,
      ...doc.customFields.values,
    ].join(' ').toLowerCase();
  }

  EstimateDocument _fromRemoteRow(Map<String, dynamic> row) {
    return EstimateDocument(
      id: (row['id'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      modelName: (row['model_name'] ?? '').toString(),
      customerName: (row['customer_name'] ?? '').toString(),
      siteName: (row['site_name'] ?? '').toString(),
      baseAmount: (row['base_amount'] as num?)?.toInt() ?? 0,
      extraItems: ((row['extra_items'] as List?) ?? const [])
          .map(
            (e) =>
                EstimateExtraItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      customFields: Map<String, String>.from(
        row['custom_fields'] as Map? ?? const {},
      ),
      memo: (row['memo'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((row['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Future<void> _saveLocalBatch(List<EstimateDocument> docs) async {
    for (final doc in docs) {
      await _upsertLocal(doc);
    }
  }
}
