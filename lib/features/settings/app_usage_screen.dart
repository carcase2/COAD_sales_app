import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/models/app_usage_summary.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class UsagePeriod {
  const UsagePeriod({
    required this.id,
    required this.menuLabel,
    required this.shortLabel,
    required this.opensLabel,
    required this.startYmd,
    required this.endYmd,
    required this.dayCount,
  });

  final String id;
  final String menuLabel;
  final String shortLabel;
  final String opensLabel;
  final String startYmd;
  final String endYmd;
  final int dayCount;

  static const List<String> ids = ['today', 'yesterday', '7', '14', '30'];

  static UsagePeriod resolve(String id) {
    final today = todayYmdSeoul();
    final yesterday = addDaysToYmd(today, -1);
    return switch (id) {
      'today' => UsagePeriod(
        id: id,
        menuLabel: '금일',
        shortLabel: '금일',
        opensLabel: '금일 실행',
        startYmd: today,
        endYmd: today,
        dayCount: 1,
      ),
      'yesterday' => UsagePeriod(
        id: id,
        menuLabel: '전일',
        shortLabel: '전일',
        opensLabel: '전일 실행',
        startYmd: yesterday,
        endYmd: yesterday,
        dayCount: 1,
      ),
      '14' => UsagePeriod(
        id: id,
        menuLabel: '최근 14일',
        shortLabel: '14일',
        opensLabel: '14일 실행',
        startYmd: addDaysToYmd(today, -13),
        endYmd: today,
        dayCount: 14,
      ),
      '30' => UsagePeriod(
        id: id,
        menuLabel: '최근 30일',
        shortLabel: '30일',
        opensLabel: '30일 실행',
        startYmd: addDaysToYmd(today, -29),
        endYmd: today,
        dayCount: 30,
      ),
      _ => UsagePeriod(
        id: '7',
        menuLabel: '최근 7일',
        shortLabel: '7일',
        opensLabel: '7일 실행',
        startYmd: addDaysToYmd(today, -6),
        endYmd: today,
        dayCount: 7,
      ),
    };
  }
}

class AppUsageScreen extends ConsumerStatefulWidget {
  const AppUsageScreen({super.key});

  @override
  ConsumerState<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends ConsumerState<AppUsageScreen> {
  String _periodId = 'today';
  bool _excludeAdmins = false;
  AsyncValue<List<AppUsageSummary>> _summaries = const AsyncLoading();

  UsagePeriod get _period => UsagePeriod.resolve(_periodId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() => _summaries = const AsyncLoading());
    try {
      final period = UsagePeriod.resolve(_periodId);
      final list = await ref
          .read(usageRepositoryProvider)
          .fetchSummaries(startYmd: period.startYmd, endYmd: period.endYmd);
      if (!mounted) return;
      setState(() => _summaries = AsyncData(list));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _summaries = AsyncError(e, st));
    }
  }

  void _selectPeriod(String id) {
    if (_periodId == id) return;
    setState(() => _periodId = id);
    unawaited(_load());
  }

  void _toggleExcludeAdmins(bool value) {
    if (_excludeAdmins == value) return;
    setState(() => _excludeAdmins = value);
  }

  List<AppUsageSummary> _visibleSummaries(List<AppUsageSummary> all) {
    if (!_excludeAdmins) return all;
    return all.where((s) => !s.isAdmin).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    if (!isAppAdmin(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('앱 사용량')),
        body: const Center(child: Text('관리자만 이용할 수 있습니다.')),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final period = _period;

    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 사용량'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '기간',
            initialValue: _periodId,
            onSelected: _selectPeriod,
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
                    period.shortLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: '사용량을 불러오지 못했습니다.\n${koreanErrorMessage(e)}',
          onRetry: () => unawaited(_load()),
        ),
        data: (summaries) {
          if (summaries.isEmpty) {
            return _ErrorBody(
              message: '${period.menuLabel} 앱 사용 기록이 없습니다.',
              onRetry: () => unawaited(_load()),
            );
          }
          final visible = _visibleSummaries(summaries);
          final adminCount = summaries.where((s) => s.isAdmin).length;
          if (visible.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _FilterBar(
                  excludeAdmins: _excludeAdmins,
                  adminCount: adminCount,
                  onChanged: _toggleExcludeAdmins,
                ),
                const SizedBox(height: 48),
                Center(
                  child: Text(
                    '관리자를 제외하면 표시할 사용자가 없습니다.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            );
          }
          final insights = AppUsageInsights.fromUsers(
            visible,
            periodDays: period.dayCount,
          );
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _FilterBar(
                  excludeAdmins: _excludeAdmins,
                  adminCount: adminCount,
                  onChanged: _toggleExcludeAdmins,
                ),
                const SizedBox(height: 12),
                Text(
                  _excludeAdmins
                      ? '${period.menuLabel} · 직원 ${insights.activeUserCount}명'
                          '${adminCount > 0 ? ' (관리자 $adminCount명 제외)' : ''}'
                      : '${period.menuLabel} · 앱 사용자 ${insights.activeUserCount}명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                _OverviewGrid(insights: insights, period: period),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.apps_rounded,
                  title: '가장 많이 쓰는 기능',
                  subtitle: insights.topFeatureKey.isEmpty
                      ? '탭 기록이 없습니다'
                      : '${appUsageTabLabel(insights.topFeatureKey)}이(가) 1위',
                ),
                const SizedBox(height: 10),
                _FeatureUsagePanel(insights: insights),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.emoji_events_outlined,
                  title: '하이라이트',
                  subtitle: '사용량·활용도 상위',
                ),
                const SizedBox(height: 10),
                _HighlightRow(insights: insights, period: period),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.leaderboard_rounded,
                  title: '직원별 순위',
                  subtitle: '실행 횟수 기준 · 활용도 함께 표시',
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < insights.byUsage.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _UsageRankCard(
                    rank: i + 1,
                    row: insights.byUsage[i],
                    period: period,
                    maxOpens: insights.byUsage.first.weekOpens,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.excludeAdmins,
    required this.adminCount,
    required this.onChanged,
  });

  final bool excludeAdmins;
  final int adminCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        avatar: Icon(
          excludeAdmins
              ? Icons.person_off_rounded
              : Icons.admin_panel_settings_outlined,
          size: 18,
          color: excludeAdmins ? scheme.onSecondaryContainer : scheme.primary,
        ),
        label: Text(
          adminCount > 0
              ? '관리자 제외${excludeAdmins ? ' · $adminCount명' : ''}'
              : '관리자 제외',
        ),
        selected: excludeAdmins,
        onSelected: onChanged,
        showCheckmark: false,
        selectedColor: scheme.secondaryContainer,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: excludeAdmins
              ? scheme.onSecondaryContainer
              : scheme.onSurface,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.insights, required this.period});

  final AppUsageInsights insights;
  final UsagePeriod period;

  @override
  Widget build(BuildContext context) {
    final avgOpens = insights.avgOpensPerUser;
    final avgDays = insights.avgActiveDays;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '활성 사용자',
                value: '${insights.activeUserCount}',
                unit: '명',
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: period.opensLabel,
                value: '${insights.totalOpens}',
                unit: '회',
                icon: Icons.play_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '탭 이동',
                value: '${insights.totalTabTaps}',
                unit: '회',
                icon: Icons.touch_app_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: '인당 평균',
                value: avgOpens >= 10
                    ? avgOpens.toStringAsFixed(0)
                    : avgOpens.toStringAsFixed(1),
                unit: '회 · ${avgDays.toStringAsFixed(1)}일',
                icon: Icons.insights_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureUsagePanel extends StatelessWidget {
  const _FeatureUsagePanel({required this.insights});

  final AppUsageInsights insights;

  IconData _iconFor(String key) => switch (key) {
        'home' => Icons.home_rounded,
        'reception' => Icons.phone_in_talk_rounded,
        'issuance' => Icons.assignment_turned_in_rounded,
        'general_schedule' => Icons.event_note_rounded,
        'menu' => Icons.menu_rounded,
        'settings' => Icons.settings_rounded,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranking = insights.featureRanking;
    if (ranking.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '아직 탭 이동 기록이 없습니다. 앱 실행만 집계된 기간일 수 있습니다.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }

    final maxCount = ranking.first.count;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ranking.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _FeatureBarRow(
              rank: i + 1,
              label: appUsageTabLabel(ranking[i].key),
              icon: _iconFor(ranking[i].key),
              count: ranking[i].count,
              maxCount: maxCount,
              total: insights.totalTabTaps,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBarRow extends StatelessWidget {
  const _FeatureBarRow({
    required this.rank,
    required this.label,
    required this.icon,
    required this.count,
    required this.maxCount,
    required this.total,
  });

  final int rank;
  final String label;
  final IconData icon;
  final int count;
  final int maxCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = maxCount <= 0 ? 0.0 : count / maxCount;
    final pct = total <= 0 ? 0 : ((count / total) * 100).round();

    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: rank == 1 ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: scheme.surface,
              color: rank == 1 ? scheme.primary : scheme.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '$count회 · $pct%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.insights, required this.period});

  final AppUsageInsights insights;
  final UsagePeriod period;

  @override
  Widget build(BuildContext context) {
    final usage = insights.topUsageUser;
    final engagement = insights.topEngagementUser;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _HighlightCard(
            badge: '많이 사용',
            icon: Icons.local_fire_department_rounded,
            accent: Theme.of(context).colorScheme.error,
            name: usage?.userName ?? '—',
            detail: usage == null
                ? '—'
                : '${usage.weekOpens}회 실행 · ${usage.activeDays}일',
            hint: '실행 횟수 1위',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HighlightCard(
            badge: '잘 사용',
            icon: Icons.verified_rounded,
            accent: Theme.of(context).colorScheme.tertiary,
            name: engagement?.userName ?? '—',
            detail: engagement == null
                ? '—'
                : '활용도 ${engagement.engagementScore(period.dayCount)} · '
                    '${engagement.distinctTabs}개 기능',
            hint: '꾸준함·기능 활용 1위',
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.badge,
    required this.icon,
    required this.accent,
    required this.name,
    required this.detail,
    required this.hint,
  });

  final String badge;
  final IconData icon;
  final Color accent;
  final String name;
  final String detail;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 4),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRankCard extends StatelessWidget {
  const _UsageRankCard({
    required this.rank,
    required this.row,
    required this.period,
    required this.maxOpens,
  });

  final int rank;
  final AppUsageSummary row;
  final UsagePeriod period;
  final int maxOpens;

  String get _initial {
    final name = row.userName.trim();
    if (name.isEmpty) return '?';
    return String.fromCharCodes(name.runes.take(1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lastUsed = row.lastUsed == null
        ? '—'
        : DateFormat('M/d HH:mm').format(row.lastUsed!);
    final score = row.engagementScore(period.dayCount);
    final bar = maxOpens <= 0 ? 0.0 : row.weekOpens / maxOpens;
    final tabEntries = row.tabCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RankBadge(rank: rank, scheme: scheme),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '주 사용 ${appUsageTabLabel(row.topTabKey)} · 마지막 $lastUsed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ScorePill(score: score, scheme: scheme),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: bar.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: scheme.surface,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                label: period.opensLabel,
                value: '${row.weekOpens}회',
                scheme: scheme,
              ),
              _StatChip(
                label: '사용일',
                value: '${row.activeDays}/${period.dayCount}일',
                scheme: scheme,
              ),
              _StatChip(
                label: '탭',
                value: '${row.totalTabTaps}회',
                scheme: scheme,
              ),
              _StatChip(
                label: '기능',
                value: '${row.distinctTabs}종',
                scheme: scheme,
              ),
            ],
          ),
          if (tabEntries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in tabEntries.take(4))
                  _MiniTabChip(
                    label: appUsageTabLabel(e.key),
                    count: e.value,
                    scheme: scheme,
                  ),
                if (tabEntries.length > 4)
                  Text(
                    '+${tabEntries.length - 4}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.scheme});

  final int rank;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isTop
            ? scheme.primary
            : scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: isTop
            ? null
            : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isTop ? scheme.onPrimary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.scheme});

  final int score;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tone = score >= 70
        ? scheme.tertiary
        : score >= 40
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '활용 $score',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _MiniTabChip extends StatelessWidget {
  const _MiniTabChip({
    required this.label,
    required this.count,
    required this.scheme,
  });

  final String label;
  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: scheme.onSurface),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
