import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sales_app_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE pending_calls (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data TEXT,
          created_at TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE estimate_documents (
          id TEXT PRIMARY KEY,
          category TEXT,
          model_name TEXT,
          customer_name TEXT,
          site_name TEXT,
          search_text TEXT,
          data TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(_createPendingConsultationsSql);
    }
  }

  static const _createPendingConsultationsSql = '''
      CREATE TABLE pending_consultations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        call_id TEXT,
        history_data TEXT,
        sales_call_body TEXT,
        include_history INTEGER,
        created_at TEXT
      )
    ''';

  Future _createDB(Database db, int version) async {
    // 1. 상담 데이터 테이블 (JSON 전체를 저장하여 복잡한 관계 처리를 단순화)
    await db.execute('''
      CREATE TABLE sales_calls (
        id TEXT PRIMARY KEY,
        data TEXT,
        status_id INTEGER,
        call_date TEXT,
        created_at TEXT
      )
    ''');

    // 2. 마스터 데이터 테이블 (제품군, 지역 등)
    await db.execute('''
      CREATE TABLE master_data (
        key TEXT PRIMARY KEY,
        data TEXT
      )
    ''');

    // 3. 오프라인 미전송 데이터 테이블
    await db.execute('''
      CREATE TABLE pending_calls (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE estimate_documents (
        id TEXT PRIMARY KEY,
        category TEXT,
        model_name TEXT,
        customer_name TEXT,
        site_name TEXT,
        search_text TEXT,
        data TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute(_createPendingConsultationsSql);
  }

  // --- Sales Call Operations ---

  Future<void> saveSalesCalls(List<Map<String, dynamic>> calls) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var call in calls) {
      batch.insert('sales_calls', {
        'id': call['id'],
        'data': jsonEncode(call),
        'status_id': call['status_id'],
        'call_date': call['call_date'],
        'created_at': call['created_at'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getSalesCalls({
    String? date,
    int? statusId,
    int? limit,
  }) async {
    final db = await instance.database;
    String where = '';
    List<dynamic> args = [];

    if (date != null) {
      where = 'call_date LIKE ?';
      args.add('$date%');
    }

    if (statusId != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'status_id = ?';
      args.add(statusId);
    }

    final res = await db.query(
      'sales_calls',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return res
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> deleteSalesCall(String id) async {
    final db = await instance.database;
    await db.delete('sales_calls', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getSalesCallById(String id) async {
    final db = await instance.database;
    final res = await db.query(
      'sales_calls',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return jsonDecode(res.first['data'] as String) as Map<String, dynamic>;
  }

  // --- Master Data Operations ---

  Future<void> saveMasterData(String key, Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.insert('master_data', {
      'key': key,
      'data': jsonEncode(data),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getMasterData(String key) async {
    final db = await instance.database;
    final res = await db.query(
      'master_data',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (res.isNotEmpty) {
      return jsonDecode(res.first['data'] as String) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('sales_calls');
    await db.delete('master_data');
    await db.delete('pending_calls');
    await db.delete('estimate_documents');
    await db.delete('pending_consultations');
  }

  // --- Pending Calls Operations ---

  Future<void> savePendingCall(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.insert('pending_calls', {
      'data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingCalls() async {
    final db = await instance.database;
    final res = await db.query('pending_calls', orderBy: 'created_at ASC');
    return res.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      return {'id': row['id'], 'data': data};
    }).toList();
  }

  Future<void> deletePendingCall(int id) async {
    final db = await instance.database;
    await db.delete('pending_calls', where: 'id = ?', whereArgs: [id]);
  }

  // --- Pending Consultations Operations (오프라인 상담 저장 큐) ---

  Future<void> savePendingConsultation({
    required String callId,
    required Map<String, dynamic> historyData,
    required Map<String, dynamic> salesCallBody,
    required bool includeHistory,
  }) async {
    final db = await instance.database;
    await db.insert('pending_consultations', {
      'call_id': callId,
      'history_data': jsonEncode(historyData),
      'sales_call_body': jsonEncode(salesCallBody),
      'include_history': includeHistory ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingConsultations() async {
    final db = await instance.database;
    final res =
        await db.query('pending_consultations', orderBy: 'created_at ASC');
    return res.map((row) {
      return {
        'id': row['id'],
        'call_id': row['call_id'],
        'history_data':
            jsonDecode(row['history_data'] as String) as Map<String, dynamic>,
        'sales_call_body': jsonDecode(row['sales_call_body'] as String)
            as Map<String, dynamic>,
        'include_history': row['include_history'] == 1,
      };
    }).toList();
  }

  Future<void> deletePendingConsultation(int id) async {
    final db = await instance.database;
    await db.delete('pending_consultations', where: 'id = ?', whereArgs: [id]);
  }
}
