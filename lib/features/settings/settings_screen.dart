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
            subtitle: const Text('Supabase 정책 및 Play 스토어를 확인합니다.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await AppUpdateService.checkAndUpdateIfNeeded(
                context,
                forceRecheck: true,
                showUpToDateMessage: true,
              );
            },
          ),
        ],
      ),
    );
  }
}
