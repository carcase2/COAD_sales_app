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
  });

  final String id;
  final String menuLabel;
  final String shortLabel;
  final String opensLabel;
  final String startYmd;
  final String endYmd;

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
      ),
      'yesterday' => UsagePeriod(
        id: id,
        menuLabel: '전일',
        shortLabel: '전일',
        opensLabel: '전일 실행',
        startYmd: yesterday,
        endYmd: yesterday,
      ),
      '14' => UsagePeriod(
        id: id,
        menuLabel: '최근 14일',
        shortLabel: '14일',
        opensLabel: '14일 실행',
        startYmd: addDaysToYmd(today, -13),
        endYmd: today,
      ),
      '30' => UsagePeriod(
        id: id,
        menuLabel: '최근 30일',
        shortLabel: '30일',
        opensLabel: '30일 실행',
        startYmd: addDaysToYmd(today, -29),
        endYmd: today,
      ),
      _ => UsagePeriod(
        id: '7',
        menuLabel: '최근 7일',
        shortLabel: '7일',
        opensLabel: '7일 실행',
        startYmd: addDaysToYmd(today, -6),
        endYmd: today,
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
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: summaries.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    '앱 사용자 ${summaries.length}명 · ${period.menuLabel}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                final row = summaries[index - 1];
                return _UsageCard(row: row, opensLabel: period.opensLabel);
              },
            ),
          );
        },
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.row, required this.opensLabel});

  final AppUsageSummary row;
  final String opensLabel;

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

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        row.userId,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  label: opensLabel,
                  value: '${row.weekOpens}회',
                  scheme: scheme,
                ),
                _StatChip(
                  label: '사용일',
                  value: '${row.activeDays}일',
                  scheme: scheme,
                ),
                _StatChip(
                  label: '주 사용',
                  value: appUsageTabLabel(row.topTabKey),
                  scheme: scheme,
                ),
                _StatChip(label: '마지막', value: lastUsed, scheme: scheme),
              ],
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
