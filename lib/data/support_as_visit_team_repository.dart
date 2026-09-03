import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/data/support_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kSupportStaffGroupNames = ['고객지원', '고객지원팀'];

List<String> parseSupportVisitTeamMembers(String raw) {
  return raw
      .split(RegExp(r'[,|·/、，\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String formatSupportVisitTeamMembers(Iterable<String> names) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in names) {
    final n = raw.trim();
    if (n.isEmpty || seen.contains(n)) continue;
    seen.add(n);
    out.add(n);
  }
  return out.join(', ');
}

class SupportAsVisitTeam {
  const SupportAsVisitTeam({
    required this.id,
    required this.branch,
    required this.name,
    this.members = '',
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String branch;
  final String name;
  final String members;
  final int sortOrder;
  final bool active;

  String get label {
    final n = name.trim();
    final m = members.trim();
    if (n.isEmpty && m.isEmpty) return '이름 없음';
    if (m.isEmpty) return n;
    if (n.isEmpty) return m;
    return '$n · $m';
  }

  SupportAsVisitTeam copyWith({
    String? name,
    String? members,
    int? sortOrder,
    bool? active,
  }) {
    return SupportAsVisitTeam(
      id: id,
      branch: branch,
      name: name ?? this.name,
      members: members ?? this.members,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
    );
  }

  factory SupportAsVisitTeam.fromJson(Map<String, dynamic> json) {
    return SupportAsVisitTeam(
      id: (json['id'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      members: (json['members'] ?? '').toString(),
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      active: json['active'] != false,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'branch': branch,
    'name': name.trim(),
    'members': members.trim(),
    'sort_order': sortOrder,
    'active': active,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class SupportAsVisitTeamRepository {
  SupportAsVisitTeamRepository({
    SupabaseClient? client,
    SupabaseClient? usersClient,
  }) : _client = client ?? supportSupabaseClient(),
       _usersClient = usersClient ?? Supabase.instance.client;

  final SupabaseClient _client;
  /// 메인 DB `users`/`groups` (고객지원 부서 인원).
  final SupabaseClient _usersClient;

  /// 고객지원·고객지원팀 그룹의 활성 사용자 이름 (가나다순).
  /// 메인 DB `users`/`groups` — 고수 담당자 조회와 동일 패턴.
  Future<List<String>> fetchCustomerSupportMemberNames() async {
    try {
      final groupsRes = await _usersClient.from('groups').select('id, name');
      final groupIds = <String>[];
      for (final raw in groupsRes as List) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = (map['name'] ?? '').toString().trim();
        if (!kSupportStaffGroupNames.contains(name)) continue;
        final id = (map['id'] ?? '').toString();
        if (id.isNotEmpty) groupIds.add(id);
      }
      if (groupIds.isEmpty) return const [];

      final usersRes = await _usersClient
          .from('users')
          .select('name, is_active, group_id')
          .inFilter('group_id', groupIds);
      final names = <String>{};
      for (final raw in usersRes as List) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (map['is_active'] == false) continue;
        final name = (map['name'] ?? '').toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
      final list = names.toList()..sort((a, b) => a.compareTo(b));
      return list;
    } catch (e) {
      throw ApiException('고객지원팀 인원을 불러오지 못했습니다. $e');
    }
  }

  Future<List<SupportAsVisitTeam>> list({
    String? branch,
    bool activeOnly = true,
  }) async {
    try {
      var query = _client.from('support_as_visit_teams').select();
      if ((branch ?? '').trim().isNotEmpty) {
        query = query.eq('branch', branch!.trim());
      }
      if (activeOnly) {
        query = query.eq('active', true);
      }
      final res = await query
          .order('branch', ascending: true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      final out = <SupportAsVisitTeam>[];
      for (final raw in res as List) {
        if (raw is! Map) continue;
        final team = SupportAsVisitTeam.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (team.id.isNotEmpty) out.add(team);
      }
      return out;
    } catch (e) {
      throw ApiException('A/S 방문 팀을 불러오지 못했습니다. $e');
    }
  }

  Future<List<SupportAsVisitTeam>> listForBranch(
    String branch, {
    bool activeOnly = true,
  }) {
    final b = branch.trim().isEmpty ? '기타' : branch.trim();
    final known = kSupportBranchTabOrder.where((e) => e != '전체').contains(b)
        ? b
        : '기타';
    return list(branch: known, activeOnly: activeOnly);
  }

  Future<SupportAsVisitTeam> upsert(SupportAsVisitTeam team) async {
    final name = team.name.trim();
    if (name.isEmpty) {
      throw ApiException('팀 이름을 입력해 주세요.');
    }
    if (!kSupportBranchTabOrder.where((e) => e != '전체').contains(team.branch)) {
      throw ApiException('지점을 확인해 주세요.');
    }
    try {
      final row = await _client
          .from('support_as_visit_teams')
          .upsert(team.toRow())
          .select()
          .single();
      return SupportAsVisitTeam.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 방문 팀을 저장하지 못했습니다. $e');
    }
  }

  Future<SupportAsVisitTeam> create({
    required String branch,
    required String name,
    String members = '',
  }) async {
    final existing = await listForBranch(branch, activeOnly: false);
    final sort = existing.isEmpty
        ? 0
        : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    try {
      final row = await _client
          .from('support_as_visit_teams')
          .insert({
            'branch': branch.trim(),
            'name': name.trim(),
            'members': members.trim(),
            'sort_order': sort,
            'active': true,
          })
          .select()
          .single();
      return SupportAsVisitTeam.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('A/S 방문 팀을 추가하지 못했습니다. $e');
    }
  }

  Future<void> setActive(String id, bool active) async {
    final tid = id.trim();
    if (tid.isEmpty) throw ApiException('팀 id가 없습니다.');
    try {
      await _client
          .from('support_as_visit_teams')
          .update({
            'active': active,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', tid);
    } catch (e) {
      throw ApiException('팀 상태를 바꾸지 못했습니다. $e');
    }
  }
}
