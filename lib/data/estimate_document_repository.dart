import 'dart:convert';

import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/models/estimate_document.dart';
import 'package:sqflite/sqflite.dart';

class EstimateDocumentRepository {
  Future<List<EstimateDocument>> list({String? query}) async {
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
    final db = await DatabaseHelper.instance.database;
    final searchText = [
      doc.category,
      doc.modelName,
      doc.customerName,
      doc.siteName,
      doc.memo,
      ...doc.customFields.values,
    ].join(' ').toLowerCase();
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
  }
}
