import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_notification.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeneralScheduleRepository {
  GeneralScheduleRepository(this._deps);

  final AppDependencies _deps;
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<GeneralScheduleRecord>> fetchAll() async {
    final res = await _client.from('sales_schedule').select('''
        id,
        site,
        start,
        end_date,
        user_id,
        created_by,
        updated_by,
        door_types,
        models,
        model_name,
        slots:schedule_slots(date, slot)
      ''');

    final rows = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (rows.isEmpty) return [];

    final userIds = <String>{};
    for (final row in rows) {
      for (final key in ['user_id', 'created_by', 'updated_by']) {
        final id = row[key]?.toString();
        if (id != null && id.isNotEmpty) userIds.add(id);
      }
    }

    final userMap = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final users = await _client
          .from('users')
          .select('id, name, role, color')
          .inFilter('id', userIds.toList());
      for (final u in users.whereType<Map>()) {
        final m = Map<String, dynamic>.from(u);
        final id = m['id']?.toString();
        if (id != null) userMap[id] = m;
      }
    }

    final parsed = <GeneralScheduleRecord>[];
    for (final row in rows) {
      _normalizeModelsField(row);
      final assigneeId =
          row['created_by']?.toString() ?? row['user_id']?.toString();
      if (assigneeId != null && userMap[assigneeId] != null) {
        row['user'] = userMap[assigneeId];
      }

      final slots = row['slots'];
      final perDate = <String, int>{};
      if (slots is List) {
        for (final s in slots) {
          if (s is! Map) continue;
          final d = s['date']?.toString();
          if (d != null) perDate[d] = (perDate[d] ?? 0) + 1;
        }
      }
      final teamCount = perDate.values.isEmpty
          ? 1
          : perDate.values.reduce((a, b) => a > b ? a : b);

      parsed.add(GeneralScheduleRecord.fromJson(row, teamCount: teamCount));
    }
    return parsed;
  }

  Future<List<DoorTypeOption>> fetchDoorTypes() async {
    final res = await _client
        .from('door_types')
        .select('code, name, color')
        .order('code');
    return res
        .whereType<Map>()
        .map((e) => DoorTypeOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<DoorModelOption>> fetchDoorModels({String? doorTypeCode}) async {
    var query = _client.from('door_models').select('id, name, door_type, color');
    if (doorTypeCode != null && doorTypeCode.isNotEmpty) {
      query = query.eq('door_type', doorTypeCode);
    }
    final res = await query.order('door_type').order('name');
    return res
        .whereType<Map>()
        .map((e) => DoorModelOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<GeneralScheduleRecord> create({
    required String site,
    required String startYmd,
    required String endYmd,
    required String userId,
    required Map<String, int> slotMap,
    List<String> doorTypes = const [],
    String? modelName,
    List<ScheduleModelEntry> models = const [],
    Map<String, List<int>>? extraTeamSlots,
  }) async {
    final insertRes = await _client
        .from('sales_schedule')
        .insert({
          'site': site,
          'start': startYmd,
          'end_date': endYmd,
          'user_id': userId,
          'created_by': userId,
          'updated_by': userId,
          'door_types': doorTypes,
          'model_name': modelName,
          'models': models.map((e) => e.toJson()).toList(),
        })
        .select()
        .single();

    final scheduleId = insertRes['id'].toString();
    await _insertSlots(scheduleId, slotMap, extraTeamSlots);

    final all = await fetchAll();
    return all.firstWhere((e) => e.id == scheduleId);
  }

  Future<void> update({
    required String id,
    required String site,
    required String startYmd,
    required String endYmd,
    required String userId,
    required Map<String, int> slotMap,
    List<String> doorTypes = const [],
    String? modelName,
    List<ScheduleModelEntry> models = const [],
    Map<String, List<int>>? extraTeamSlots,
  }) async {
    await _client.from('sales_schedule').update({
      'site': site,
      'start': startYmd,
      'end_date': endYmd,
      'updated_by': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'door_types': doorTypes,
      'model_name': modelName,
      'models': models.map((e) => e.toJson()).toList(),
    }).eq('id', id);

    await _client.from('schedule_slots').delete().eq('schedule_id', id);
    await _insertSlots(id, slotMap, extraTeamSlots);
  }

  Future<void> delete(String id) async {
    await _client.from('sales_schedule').delete().eq('id', id);
  }

  /// enrich 실패 시 [base]만으로 FCM 전송 (접수 등록과 동일하게 await 호출).
  Future<void> dispatchGeneralScheduleNotification({
    required String action,
    required Map<String, dynamic> base,
    required GeneralScheduleRecord record,
    required String actorName,
  }) async {
    Map<String, dynamic> payload;
    try {
      payload = await enrichScheduleNotificationData(
        base: base,
        record: record,
        actorName: actorName,
      );
    } catch (e) {
      debugPrint('[dispatchGeneralScheduleNotification] enrich failed: $e');
      payload = base;
    }
    await notifyGeneralSchedulePush(action: action, scheduleData: payload);
  }

  /// 본사영업·관리자 FCM 알림 (`notify-new-call` / `notify-issuance-request`와 동일 패턴).
  Future<void> notifyGeneralSchedulePush({
    required String action,
    required Map<String, dynamic> scheduleData,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'notify-general-schedule',
        body: {
          'action': action,
          'scheduleData': scheduleData,
        },
      );
      debugPrint(
        '[notify-general-schedule] status=${res.status} data=${res.data}',
      );
      if (res.status >= 400) {
        debugPrint(
          '[notify-general-schedule] push invoke returned error status=${res.status}',
        );
      }
    } catch (e, st) {
      debugPrint('[notify-general-schedule] invoke failed: $e');
      debugPrint('$st');
    }
  }

  /// 알림 본문 강화 실패 시에도 기본 payload로 FCM은 보냄.
  Future<Map<String, dynamic>> enrichScheduleNotificationData({
    required Map<String, dynamic> base,
    required GeneralScheduleRecord record,
    required String actorName,
  }) async {
    try {
      final all = await fetchAll();
      final grid = buildGeneralScheduleGrid(all);
      final alarm = buildGeneralScheduleAlarmContext(
        grid: grid,
        record: record,
        actorName: actorName,
        todayYmd: todayYmdSeoul(),
      );
      return mergeGeneralScheduleTelegramPayload(base: base, alarm: alarm);
    } catch (e) {
      debugPrint('[enrichScheduleNotificationData] failed, using base: $e');
      return base;
    }
  }

  Future<void> _insertSlots(
    String scheduleId,
    Map<String, int> slotMap,
    Map<String, List<int>>? extraTeamSlots,
  ) async {
    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(String date, int slot) {
      final key = '$date|$slot';
      if (seen.contains(key)) return;
      seen.add(key);
      rows.add({
        'schedule_id': scheduleId,
        'date': date,
        'slot': slot,
      });
    }

    slotMap.forEach(add);
    if (extraTeamSlots != null) {
      for (final entry in extraTeamSlots.entries) {
        final slots = entry.value;
        for (var i = 1; i < slots.length; i++) {
          add(entry.key, slots[i]);
        }
      }
    }

    if (rows.isEmpty) {
      throw ApiException('배치할 slot이 없습니다.');
    }
    await _client.from('schedule_slots').insert(rows);
  }

  void _normalizeModelsField(Map<String, dynamic> row) {
    final raw = row['models'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        row['models'] = jsonDecode(raw);
      } catch (_) {
        row['models'] = [];
      }
    }
  }
}