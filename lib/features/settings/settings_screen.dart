import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: scheme.primary),
            title: const Text('앱 버전'),
            subtitle: Text('v$kAppVersion'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.system_update_alt_rounded, color: scheme.primary),
            title: const Text('업데이트 확인'),
            subtitle: const Text('Play 스토어에서 최신 버전으로 업데이트를 시도합니다.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await AppUpdateService.checkAndUpdateIfNeeded(
                context,
                forceRecheck: true,
                showUpToDateMessage: true,
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            '업데이트 내역',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<UpdateHistoryEntry>>(
            future: AppUpdateService.fetchUpdateHistory(limit: 10),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snapshot.data ?? const <UpdateHistoryEntry>[];
              if (items.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '등록된 업데이트 내역이 없습니다.',
                      style: TextStyle(fontSize: 13.5),
                    ),
                  ),
                );
              }

              return Column(
                children: items
                    .map((item) => _UpdateHistoryCard(item: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpdateHistoryCard extends StatelessWidget {
  const _UpdateHistoryCard({required this.item});

  final UpdateHistoryEntry item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.new_releases_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'v${item.version}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Text(
                  item.dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '제안: ${item.proposer}',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...item.changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $change',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
