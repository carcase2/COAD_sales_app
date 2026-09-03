import 'dart:async';

import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 본사·지사별 A/S 방문 팀 이름·팀원 설정 (서버 공유).
class SupportVisitTeamsScreen extends ConsumerStatefulWidget {
  const SupportVisitTeamsScreen({super.key, this.initialBranch = '본사'});

  final String initialBranch;

  @override
  ConsumerState<SupportVisitTeamsScreen> createState() =>
      _SupportVisitTeamsScreenState();
}

class _SupportVisitTeamsScreenState
    extends ConsumerState<SupportVisitTeamsScreen>
    with SingleTickerProviderStateMixin {
  static const _branches = ['본사', '대구', '대전', '전남', '기타'];

  late final TabController _tabs;
  List<SupportAsVisitTeam> _teams = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final i = _branches.indexOf(widget.initialBranch);
    _tabs = TabController(
      length: _branches.length,
      vsync: this,
      initialIndex: i < 0 ? 0 : i,
    );
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) unawaited(_load());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _branch => _branches[_tabs.index];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(supportAsVisitTeamRepositoryProvider)
          .listForBranch(_branch, activeOnly: false);
      if (!mounted) return;
      setState(() {
        _teams = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _editTeam(SupportAsVisitTeam? existing) async {
    List<String> staff;
    try {
      staff = await ref
          .read(supportAsVisitTeamRepositoryProvider)
          .fetchCustomerSupportMemberNames();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
      return;
    }
    if (!mounted) return;
    if (staff.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('고객지원팀 부서 인원이 없습니다. 인트라넷 그룹을 확인해 주세요.'),
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final selected = parseSupportVisitTeamMembers(
      existing?.members ?? '',
    ).toSet();
    // 예전에 수동 입력한 이름이 DB에 없으면 목록에 남겨 선택 유지.
    for (final name in [...selected]) {
      if (!staff.contains(name)) staff = [...staff, name];
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final scheme = Theme.of(ctx).colorScheme;
            return AlertDialog(
              title: Text(existing == null ? '팀 추가' : '팀 수정'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '팀 이름',
                          hintText: '예: 1팀',
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '팀원 (고객지원팀 부서 · 나중에 골라도 됩니다)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final name in staff)
                            FilterChip(
                              label: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: selected.contains(name),
                              onSelected: (on) {
                                setLocal(() {
                                  if (on) {
                                    selected.add(name);
                                  } else {
                                    selected.remove(name);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
    final name = nameCtrl.text.trim();
    final members = formatSupportVisitTeamMembers(selected);
    nameCtrl.dispose();
    if (ok != true || !mounted) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팀 이름을 입력해 주세요.')));
      return;
    }
    try {
      if (existing == null) {
        await ref
            .read(supportAsVisitTeamRepositoryProvider)
            .create(branch: _branch, name: name, members: members);
      } else {
        await ref
            .read(supportAsVisitTeamRepositoryProvider)
            .upsert(existing.copyWith(name: name, members: members));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  Future<void> _toggleActive(SupportAsVisitTeam team) async {
    try {
      await ref
          .read(supportAsVisitTeamRepositoryProvider)
          .setActive(team.id, !team.active);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(koreanErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    return Scaffold(
      appBar: AppBar(
        title: const Text('A/S 방문 팀'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final b in _branches) Tab(text: b)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_editTeam(null)),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('팀 추가'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Text(
              '$_branch · 하루 ${_teams.where((t) => t.active).length}팀 가능. 팀원은 고객지원팀 부서 인원에서 고릅니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  koreanErrorMessage(_error!),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            if (!_loading && _teams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  '등록된 팀이 없습니다. 아래 + 로 추가하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final team in _teams)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (team.active ? accent : scheme.outline)
                        .withValues(alpha: 0.16),
                    child: Text(
                      '${team.sortOrder + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: team.active ? accent : scheme.outline,
                      ),
                    ),
                  ),
                  title: Text(
                    team.name.trim().isEmpty ? '이름 없음' : team.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: team.active
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (team.members.trim().isNotEmpty) team.members.trim(),
                      team.active ? '사용 중' : '숨김',
                    ].join(' · '),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') unawaited(_editTeam(team));
                      if (v == 'toggle') unawaited(_toggleActive(team));
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(team.active ? '숨기기' : '다시 쓰기'),
                      ),
                    ],
                  ),
                  onTap: () => unawaited(_editTeam(team)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 팀 설정 화면을 연다.
Future<void> openSupportVisitTeamsScreen(
  BuildContext context, {
  String initialBranch = '본사',
}) {
  final branch = kSupportBranchTabOrder
          .where((e) => e != '전체')
          .contains(initialBranch)
      ? initialBranch
      : '본사';
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SupportVisitTeamsScreen(initialBranch: branch),
    ),
  );
}
