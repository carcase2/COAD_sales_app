class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.permissions,
    this.groupId,
    this.groupName,
    this.title,
    this.branchId,
    this.branchName,
  });

  final String id;
  final String name;
  final String role;
  final List<String> permissions;
  final String? groupId;
  final String? groupName;
  final String? title;
  final String? branchId;
  final String? branchName;

  static const _hqBranchId = '6d13d1d1-50a8-47da-b127-40298b0f8aaf';
  static const _daeguBranchId = 'a34901c1-99c6-4142-a92c-128d82d06181';

  bool get isHqBranch {
    if ((branchId ?? '').trim() == _hqBranchId) return true;
    final n = (branchName ?? '').trim();
    return n == '본사' || n.toLowerCase() == 'hq';
  }

  bool get isDaeguBranch {
    if ((branchId ?? '').trim() == _daeguBranchId) return true;
    final n = (branchName ?? '').trim();
    return n == '대구지사' || n == '대구' || n.contains('대구');
  }

  /// 부서 영업 + 지사 본사 (박정훈·김인엽·이상호·이상수)
  bool get isHqSales {
    final group = groupName?.trim();
    if (group == '본사영업') return true;
    return group == '영업' && isHqBranch;
  }

  /// 부서 영업 + 지사 대구 + 직책 지사장
  bool get isSalesDaeguBranchManager {
    return (groupName?.trim() == '영업') &&
        (title?.trim() == '지사장') &&
        isDaeguBranch;
  }

  /// 헤더·서랍: `본사, 팀원`
  String get branchTitleLabel {
    final branch = branchName?.trim();
    final job = title?.trim();
    final b = (branch != null && branch.isNotEmpty) ? branch : '지사 미지정';
    final t = (job != null && job.isNotEmpty) ? job : '팀원';
    return '$b, $t';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'permissions': permissions,
        if (groupId != null) 'group_id': groupId,
        if (groupName != null) 'group_name': groupName,
        if (title != null) 'title': title,
        if (branchId != null) 'branch_id': branchId,
        if (branchName != null) 'branch_name': branchName,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    final raw = json['permissions'];
    if (raw is List) {
      perms = raw.map((e) => e.toString()).toList();
    }
    String? branchName = _str(json, const ['branch_name', 'branchName']);
    final nested = json['coad_branch'];
    if ((branchName == null || branchName.isEmpty) && nested is Map) {
      branchName = nested['name']?.toString();
    }
    return AppUser(
      id: _str(json, const ['id']) ?? '',
      name: _str(json, const ['name']) ?? '',
      role: _str(json, const ['role']) ?? '',
      permissions: perms,
      groupId: _str(json, const ['group_id', 'groupId']),
      groupName: _str(json, const ['group_name', 'groupName']),
      title: _str(json, const ['title']),
      branchId: _str(json, const ['branch_id', 'branchId']),
      branchName: branchName,
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
