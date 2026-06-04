import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/providers/app_update_provider.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _flowUncalledPopupEnabled;

  @override
  void initState() {
    super.initState();
    _loadFlowUncalledPref();
  }

  Future<void> _loadFlowUncalledPref() async {
    final prefs = ref.read(appDependenciesProvider).prefs;
    final enabled = prefs.getBool(homeFlowUncalledPopupPrefKey) ?? true;
    if (!mounted) return;
    setState(() => _flowUncalledPopupEnabled = enabled);
  }

  Future<void> _setFlowUncalledPopupEnabled(bool enabled) async {
    setState(() => _flowUncalledPopupEnabled = enabled);
    final prefs = ref.read(appDependenciesProvider).prefs;
    await prefs.setBool(homeFlowUncalledPopupPrefKey, enabled);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updateStatus = ref.watch(appUpdateStatusProvider).valueOrNull;
    final loginName = ref.watch(authControllerProvider)?.name.trim();
    final flowPopupOn = _flowUncalledPopupEnabled ?? true;

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
            subtitle: Text(
              updateStatus?.hasUpdate == true
                  ? (updateStatus?.latestVersion != null
                      ? '새 버전 v${updateStatus!.latestVersion} 사용 가능 · 탭하여 업데이트'
                      : '새 버전 사용 가능 · 탭하여 업데이트')
                  : 'Play 스토어에서 최신 버전으로 업데이트를 시도합니다.',
            ),
            trailing: updateStatus?.hasUpdate == true
                ? Icon(Icons.new_releases_rounded, color: scheme.tertiary)
                : const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              ref.invalidate(appUpdateStatusProvider);
              await AppUpdateService.checkAndUpdateIfNeeded(
                context,
                forceRecheck: true,
                showUpToDateMessage: true,
              );
              if (!context.mounted) return;
              ref.invalidate(appUpdateStatusProvider);
              await ref.read(appUpdateStatusProvider.future);
            },
          ),
          const SizedBox(height: 16),
          Text(
            '흐름 · 미통화',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: flowPopupOn,
            onChanged: _flowUncalledPopupEnabled == null
                ? null
                : _setFlowUncalledPopupEnabled,
            title: const Text(
              '흐름에서 내 미통화 0건 안내',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              flowPopupOn
                  ? '켜짐 · 선택 기간에 미통화가 0건이면 안내 팝업(새로고침과 무관)'
                  : '꺼짐 · 미통화 0건이어도 담당자 선택 화면으로 이동',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
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

              if (snapshot.hasError) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '업데이트 내역을 불러오지 못했습니다.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
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
            if (!item.hasPerItemProposer) ...[
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
            ] else
              const SizedBox(height: 8),
            ...item.changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${change.text}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (item.hasPerItemProposer) ...[
                      const SizedBox(height: 2),
                      Text(
                        '제안: ${change.proposer}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
