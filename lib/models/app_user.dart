class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.permissions,
    this.groupId,
    this.groupName,
  });

  final String id;
  final String name;
  final String role;
  final List<String> permissions;
  final String? groupId;
  final String? groupName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'permissions': permissions,
        if (groupId != null) 'group_id': groupId,
        if (groupName != null) 'group_name': groupName,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    final raw = json['permissions'];
    if (raw is List) {
      perms = raw.map((e) => e.toString()).toList();
    }
    return AppUser(
      id: _str(json, const ['id']) ?? '',
      name: _str(json, const ['name']) ?? '',
      role: _str(json, const ['role']) ?? '',
      permissions: perms,
      groupId: _str(json, const ['group_id', 'groupId']),
      groupName: _str(json, const ['group_name', 'groupName']),
    );
  }
}

String? _str(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) return v.toString();
  }
  return null;
}
