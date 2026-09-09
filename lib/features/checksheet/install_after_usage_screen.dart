import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/settings/app_usage_screen.dart';
import 'package:coad_customer_calls/models/install_after_usage.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 시공 사진 검색 기록 · 사용자별 순위 (관리자 그룹만).
class InstallAfterUsageScreen extends ConsumerStatefulWidget {
  const InstallAfterUsageScreen({super.key});

  @override
  ConsumerState<InstallAfterUsageScreen> createState() =>
      _InstallAfterUsageScreenState();
}

class _InstallAfterUsageScreenState
    extends ConsumerState<InstallAfterUsageScreen> {
  String _periodId = '7';
  bool _excludeAdmins = false;
  bool _searchesOnly = true;
  AsyncValue<InstallAfterUsageReport> _data = const AsyncLoading();

  UsagePeriod get _period => UsagePeriod.resolve(_periodId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() => _data = const AsyncLoading());
    try {
      final period = UsagePeriod.resolve(_periodId);
      final report = await ref.read(usageRepositoryProvider).fetchInstallAfterUsage(
            startYmd: period.startYmd,
            endYmd: period.endYmd,
          );
      if (!mounted) return;
      setState(() => _data = AsyncData(report));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _data = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!isAdminGroup(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('시공 사진 검색 기록')),
        body: const AppEmpty(
          message: '관리자 그룹만 조회할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('시공 사진 검색 기록'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '기간',
            initialValue: _periodId,
            onSelected: (id) {
              if (id == _periodId) return;
              setState(() => _periodId = id);
              unawaited(_load());
            },
            itemBuilder: (context) => [
              for (final id in UsagePeriod.ids)
                PopupMenuItem(
                  value: id,
                  child: Text(UsagePeriod.resolve(id).menuLabel),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _period.shortLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              HapticFeedback.selectionClick();
              unawaited(_load());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _data.when(
        loading: () => const AppLoading(message: '검색 기록 불러오는 중…'),
        error: (e, _) => AppErrorState(
          message: koreanErrorMessage(e),
          onRetry: () => unawaited(_load()),
        ),
        data: (report) {
          final adminIds = {
            for (final r in report.ranks)
              if (r.isAdmin) r.userId,
          };
          final ranks = _excludeAdmins
              ? report.ranks.where((r) => !r.isAdmin).toList()
              : report.ranks;
          final logs = report.logs.where((l) {
            if (_excludeAdmins && adminIds.contains(l.userId)) return false;
            if (_searchesOnly && !l.isSearch) return false;
            return true;
          }).toList();

          final searchSum = ranks.fold<int>(0, (s, r) => s + r.searches);
          final viewSum = ranks.fold<int>(0, (s, r) => s + r.views);
          final dlSum = ranks.fold<int>(0, (s, r) => s + r.downloads);
          final adminCount = report.ranks.where((r) => r.isAdmin).length;
          final top = ranks.isEmpty ? null : ranks.first;
          final grouped = _groupLogsByDay(logs);

          if (report.logs.isEmpty) {
            return AppEmpty(
              message:
                  '${_period.menuLabel} 시공 사진 검색 기록이 없습니다.\n검색하면 여기에 쌓입니다.',
              icon: Icons.photo_library_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _excludeAdmins,
                  onChanged: (v) => setState(() => _excludeAdmins = v),
                  title: const Text(
                    '관리자 제외',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    adminCount > 0 ? '관리자 $adminCount명' : '관리자 없음',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_period.menuLabel} · ${ranks.length}명 · 검색 $searchSum회',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        label: '검색',
                        value: '$searchSum',
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: '열람',
                        value: '$viewSum',
                        color: scheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: '저장',
                        value: '$dlSum',
                        color: scheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (top != null) ...[
                  const SizedBox(height: 16),
                  _TopSearcherCard(rank: top),
                ],
                const SizedBox(height: 22),
                Text(
                  '많이 검색한 사람',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '검색 횟수 기준 · ${_period.menuLabel}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (ranks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '관리자를 제외하면 표시할 사용자가 없습니다.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  for (var i = 0; i < ranks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _UserRankCard(
                      rank: i + 1,
                      row: ranks[i],
                      maxSearches: ranks.first.searches,
                    ),
                  ],
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '검색 기록',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('검색만'),
                      selected: _searchesOnly,
                      onSelected: (v) => setState(() => _searchesOnly = v),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _searchesOnly
                      ? '누가 · 어떤 모델 · 현장명으로 검색했는지'
                      : '검색 · 열람 · 저장을 시간순으로',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (grouped.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '이 조건에 맞는 기록이 없습니다.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  for (final day in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 8),
                      child: Text(
                        day.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final log in day.value) ...[
                      _LogTile(log: log),
                      const SizedBox(height: 8),
                    ],
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

Map<String, List<InstallAfterSearchLog>> _groupLogsByDay(
  List<InstallAfterSearchLog> logs,
) {
  final map = <String, List<InstallAfterSearchLog>>{};
  for (final log in logs) {
    final ymd = ymdSeoulFromDateTime(log.createdAt);
    final parts = ymd.split('-');
    final label = parts.length == 3
        ? '${int.tryParse(parts[1]) ?? parts[1]}월 ${int.tryParse(parts[2]) ?? parts[2]}일'
        : ymd;
    map.putIfAbsent(label, () => []).add(log);
  }
  return map;
}

class _TopSearcherCard extends StatelessWidget {
  const _TopSearcherCard({required this.rank});

  final InstallAfterUserRank rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: scheme.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '가장 많이 검색',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  rank.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${rank.searches}회',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRankCard extends StatelessWidget {
  const _UserRankCard({
    required this.rank,
    required this.row,
    required this.maxSearches,
  });

  final int rank;
  final InstallAfterUserRank row;
  final int maxSearches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dt = row.lastAt != null
        ? DateFormat('MM.dd HH:mm').format(row.lastAt!.toLocal())
        : null;
    final bar =
        maxSearches <= 0 ? 0.0 : (row.searches / maxSearches).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: rank <= 3
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: rank <= 3
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        [
                          if (row.isAdmin) '관리자',
                          if (dt != null) '최근 $dt',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '검색 ${row.searches}회',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _MiniTag(label: '검색 ${row.searches}'),
                _MiniTag(label: '열람 ${row.views}'),
                _MiniTag(label: '저장 ${row.downloads}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final InstallAfterSearchLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm').format(log.createdAt.toLocal());
    final result = log.isSearch && log.resultCount != null
        ? ' · ${log.resultCount}곳'
        : '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    log.actionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.userName.isEmpty ? log.userId : log.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.modelDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    '${log.queryDisplay}$result',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
