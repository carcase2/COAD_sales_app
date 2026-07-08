import 'package:coad_customer_calls/models/app_usage_summary.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final appUsageSummariesProvider = FutureProvider.autoDispose
    .family<List<AppUsageSummary>, int>((ref, days) async {
  final repo = ref.watch(usageRepositoryProvider);
  return repo.fetchSummaries(days: days);
});

class AppUsageScreen extends ConsumerStatefulWidget {
  const AppUsageScreen({super.key});

  @override
  ConsumerState<AppUsageScreen> createState() => _AppUsageScreenState();
}

class _AppUsageScreenState extends ConsumerState<AppUsageScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summariesAsync = ref.watch(appUsageSummariesProvider(_days));

    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 사용량'),
        actions: [
          PopupMenuButton<int>(
            tooltip: '기간',
            initialValue: _days,
            onSelected: (days) => setState(() => _days = days),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 7, child: Text('최근 7일')),
              PopupMenuItem(value: 14, child: Text('최근 14일')),
              PopupMenuItem(value: 30, child: Text('최근 30일')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_days일',
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
      body: summariesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: '사용량을 불러오지 못했습니다.\n$e',
          onRetry: () => ref.invalidate(appUsageSummariesProvider(_days)),
        ),
        data: (summaries) {
          if (summaries.isEmpty) {
            return _ErrorBody(
              message: '최근 $_days일간 기록된 사용량이 없습니다.',
              onRetry: () => ref.invalidate(appUsageSummariesProvider(_days)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(appUsageSummariesProvider(_days));
              await ref.read(appUsageSummariesProvider(_days).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: summaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = summaries[index];
                return _UsageCard(row: row, days: _days);
              },
            ),
          );
        },
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.row, required this.days});

  final AppUsageSummary row;
  final int days;

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
                    row.userName.isNotEmpty ? row.userName.characters.first : '?',
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
                  label: '$days일 실행',
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
                _StatChip(
                  label: '마지막',
                  value: lastUsed,
                  scheme: scheme,
                ),
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
