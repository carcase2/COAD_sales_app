class ScheduleModelEntry {
  const ScheduleModelEntry({
    required this.name,
    required this.quantity,
    this.color,
  });

  final String name;
  final int quantity;
  final String? color;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (color != null) 'color': color,
      };

  factory ScheduleModelEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleModelEntry(
      name: (json['name'] ?? '').toString(),
      quantity: _int(json['quantity']) ?? 0,
      color: json['color']?.toString(),
    );
  }
}

class GeneralScheduleRecord {
  const GeneralScheduleRecord({
    required this.id,
    required this.site,
    required this.start,
    required this.endDate,
    this.userId,
    this.userName,
    this.userColor,
    this.createdBy,
    this.updatedBy,
    this.doorTypes = const [],
    this.modelName,
    this.models = const [],
    this.slots = const [],
    this.teamCount = 1,
  });

  final String id;
  final String site;
  final String start;
  final String endDate;
  final String? userId;
  final String? userName;
  final String? userColor;
  final String? createdBy;
  final String? updatedBy;
  final List<String> doorTypes;
  final String? modelName;
  final List<ScheduleModelEntry> models;
  final List<({String date, int slot})> slots;
  final int teamCount;

  factory GeneralScheduleRecord.fromJson(
    Map<String, dynamic> json, {
    int teamCount = 1,
  }) {
    final slotsRaw = json['slots'];
    final slots = <({String date, int slot})>[];
    if (slotsRaw is List) {
      for (final s in slotsRaw) {
        if (s is! Map) continue;
        final date = s['date']?.toString();
        final slot = _int(s['slot']);
        if (date != null && slot != null) {
          slots.add((date: date, slot: slot));
        }
      }
    }

    List<ScheduleModelEntry> models = [];
    final modelsRaw = json['models'];
    if (modelsRaw is List) {
      models = modelsRaw
          .whereType<Map>()
          .map((e) => ScheduleModelEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final doorRaw = json['door_types'];
    List<String> doorTypes = [];
    if (doorRaw is List) {
      doorTypes = doorRaw.map((e) => e.toString()).toList();
    }

    final user = json['user'];
    String? userName;
    String? userColor;
    if (user is Map) {
      userName = user['name']?.toString();
      userColor = user['color']?.toString();
    }

    return GeneralScheduleRecord(
      id: (json['id'] ?? '').toString(),
      site: (json['site'] ?? '').toString(),
      start: (json['start'] ?? '').toString(),
      endDate: (json['end_date'] ?? json['end'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      userName: userName,
      userColor: userColor,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      doorTypes: doorTypes,
      modelName: json['model_name']?.toString(),
      models: models,
      slots: slots,
      teamCount: teamCount,
    );
  }
}

/// 달력 그리드 한 칸 — [GeneralScheduleRecord] 참조 + 해당 날짜·슬롯.
class GeneralScheduleCell {
  const GeneralScheduleCell({
    required this.scheduleId,
    required this.site,
    required this.start,
    required this.endDate,
    this.userName,
    this.userColor,
    this.doorTypes = const [],
    this.models = const [],
    this.teamCount = 1,
  });

  final String scheduleId;
  final String site;
  final String start;
  final String endDate;
  final String? userName;
  final String? userColor;
  final List<String> doorTypes;
  final List<ScheduleModelEntry> models;
  final int teamCount;
}

class DoorTypeOption {
  const DoorTypeOption({
    required this.code,
    required this.name,
    this.color,
  });

  final String code;
  final String name;
  final String? color;

  factory DoorTypeOption.fromJson(Map<String, dynamic> json) {
    return DoorTypeOption(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      color: json['color']?.toString(),
    );
  }
}

class DoorModelOption {
  const DoorModelOption({
    required this.id,
    required this.name,
    required this.doorTypeCode,
    this.color,
  });

  final String id;
  final String name;
  final String doorTypeCode;
  final String? color;

  factory DoorModelOption.fromJson(Map<String, dynamic> json) {
    return DoorModelOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      doorTypeCode: (json['door_type'] ?? '').toString(),
      color: json['color']?.toString(),
    );
  }
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}