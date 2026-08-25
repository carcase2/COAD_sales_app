import 'dart:io';

import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/data/mes_repository.dart';
import 'package:http/http.dart' as http;

class MesPhotoQueue {
  static Future<void> enqueue({required String orderId, required File file}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('pending_mes_photos', {
      'order_id': orderId,
      'file_path': file.path,
      'original_name': file.path.split(Platform.pathSeparator).last,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> flush(MesRepository repo) async {
    if (mesApiUrl.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('pending_mes_photos');
    for (final row in rows) {
      try {
        final path = row['file_path'] as String;
        final f = File(path);
        if (!await f.exists()) {
          await db.delete('pending_mes_photos', where: 'id = ?', whereArgs: [row['id']]);
          continue;
        }
        final req = http.MultipartRequest('POST', Uri.parse('$mesApiUrl/api/uploads'));
        req.files.add(await http.MultipartFile.fromPath('file', path));
        req.fields['orderId'] = '${row['order_id']}';
        req.fields['entityType'] = 'installation';
        req.fields['category'] = 'TP3_INSTALL_AFTER';
        req.fields['clientUploadId'] = '${row['id']}';
        final token = repo.token;
        if (token != null) req.headers['Authorization'] = 'Bearer $token';
        final res = await req.send();
        if (res.statusCode == 200) {
          await db.delete('pending_mes_photos', where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (_) {}
    }
  }
}
