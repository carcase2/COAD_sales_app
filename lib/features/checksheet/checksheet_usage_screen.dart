import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/settings/app_usage_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 체크시트 사용 내역 · 사용자별 순위 (관리자).
class ChecksheetUsageScreen extends ConsumerStatefulWidget {
  const ChecksheetUsageScreen({super.key});

  @override
  ConsumerState<ChecksheetUsageScreen> createState() =>
      _ChecksheetUsageScreenState();
}

class _ChecksheetRow {
  const _ChecksheetRow({
    required this.userId,
    required this.userName,
    required this.opens,
    required this.searches,
    required this.views,
    required this.downloads,
    required this.activeDays,
    this.lastUsed,
    this.isAdmin = false,
  });

  final String userId;
  final String userName;
  final int opens;
  final int searches;
  final int views;
  final int downloads;
  final int activeDays;
  final DateTime? lastUsed;
  final bool isAdmin;

  int get total => opens + searches + views + downloads;

  /// 검색·열람·저장을 고루 쓰면 높은 점수 (0~100).
  int get qualityScore {
    if (total <= 0) return 0;
    // 단순 열기만 많으면 낮음, 검색·열람·저장이 있으면 높음
    final searchShare = searches / total;
    final viewShare = views / total;
    final dlShare = downloads / total;
    final depth = (searchShare * 35) + (viewShare * 40) + (dlShare * 25);
    final volume = (total / 30).clamp(0.0, 1.0) * 20;
    return (depth + volume).round().clamp(0, 100);
  }
}

class _ChecksheetUsageScreenState extends ConsumerState<ChecksheetUsageScreen> {
  String _periodId = '7';
  bool _excludeAdmins = false;
  AsyncValue<List<_ChecksheetRow>> _rows = const AsyncLoading();

  UsagePeriod get _period => UsagePeriod.resolve(_periodId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() => _rows = const AsyncLoading());
    try {
      final period = UsagePeriod.resolve(_periodId);
      final summaries = await ref.read(usageRepositoryProvider).fetchSummaries(
            startYmd: period.startYmd,
            endYmd: period.endYmd,
          );
      final rows = <_ChecksheetRow>[];
      for (final s in summaries) {
        final opens = s.tabCounts['checksheet'] ?? 0;
        final searches = s.tabCounts['checksheet_search'] ?? 0;
        final views = s.tabCounts['checksheet_view'] ?? 0;
        final downloads = s.tabCounts['checksheet_download'] ?? 0;
        final total = opens + searches + views + downloads;
        if (total <= 0) continue;
        rows.add(
          _ChecksheetRow(
            userId: s.userId,
            userName: s.userName,
            opens: opens,
            searches: searches,
            views: views,
            downloads: downloads,
            activeDays: s.activeDays,
            lastUsed: s.lastUsed,
            isAdmin: s.isAdmin,
          ),
        );
      }
      rows.sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        if (byTotal != 0) return byTotal;
        final byQuality = b.qualityScore.compareTo(a.qualityScore);
        if (byQuality != 0) return byQuality;
        return a.userName.compareTo(b.userName);
      });
      if (!mounted) return;
      setState(() => _rows = AsyncData(rows));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _rows = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (!isAdminGroup(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('체크시트 사용 내역')),
        body: const AppEmpty(
          message: '관리자 그룹만 조회할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('체크시트 사용 내역'),
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
      body: _rows.when(
        loading: () => const AppLoading(message: '사용 내역 불러오는 중…'),
        error: (e, _) => AppErrorState(
          message: koreanErrorMessage(e),
          onRetry: () => unawaited(_load()),
        ),
        data: (all) {
          final adminCount = all.where((r) => r.isAdmin).length;
          final rows = _excludeAdmins
              ? all.where((r) => !r.isAdmin).toList()
              : all;

          if (all.isEmpty) {
            return AppEmpty(
              message:
                  '${_period.menuLabel} 체크시트 사용 기록이 없습니다.\n검색·열람이 쌓이면 여기에 표시됩니다.',
              icon: Icons.fact_check_outlined,
            );
          }

          final totalActions = rows.fold<int>(0, (s, r) => s + r.total);
          final totalSearch = rows.fold<int>(0, (s, r) => s + r.searches);
          final totalView = rows.fold<int>(0, (s, r) => s + r.views);
          final totalDl = rows.fold<int>(0, (s, r) => s + r.downloads);
          final byQuality = List<_ChecksheetRow>.from(rows)
            ..sort((a, b) {
              final q = b.qualityScore.compareTo(a.qualityScore);
              if (q != 0) return q;
              return b.total.compareTo(a.total);
            });

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
                const SizedBox(height: 8),
                Text(
                  '${_period.menuLabel} · 사용자 ${rows.length}명 · 총 $totalActions회',
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
                        value: '$totalSearch',
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: '열람',
                        value: '$totalView',
                        color: scheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatChip(
                        label: '저장',
                        value: '$totalDl',
                        color: scheme.secondary,
                      ),
                    ),
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    '많이 쓰는 사람',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '총 사용 횟수 기준',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _UserUsageCard(
                      rank: i + 1,
                      row: rows[i],
                      maxTotal: rows.first.total,
                      emphasize: 'usage',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    '잘 쓰는 사람',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '검색·열람·저장을 고루 쓰는 활용도 점수',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < byQuality.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _UserUsageCard(
                      rank: i + 1,
                      row: byQuality[i],
                      maxTotal: byQuality.first.total,
                      emphasize: 'quality',
                    ),
                  ],
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text(
                        '관리자를 제외하면 표시할 사용자가 없습니다.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
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

class _UserUsageCard extends StatelessWidget {
  const _UserUsageCard({
    required this.rank,
    required this.row,
    required this.maxTotal,
    required this.emphasize,
  });

  final int rank;
  final _ChecksheetRow row;
  final int maxTotal;
  final String emphasize; // usage | quality

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dt = row.lastUsed != null
        ? DateFormat('MM.dd HH:mm').format(row.lastUsed!.toLocal())
        : null;
    final bar = maxTotal <= 0 ? 0.0 : (row.total / maxTotal).clamp(0.0, 1.0);

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
                          '활동 ${row.activeDays}일',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      emphasize == 'quality'
                          ? '활용 ${row.qualityScore}'
                          : '총 ${row.total}회',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      emphasize == 'quality'
                          ? '총 ${row.total}회'
                          : '활용 ${row.qualityScore}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                _MiniTag(label: '열기 ${row.opens}'),
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
