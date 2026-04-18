import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    final deps = ref.read(appDependenciesProvider);
    _urlCtrl = TextEditingController(text: _savedOrEmpty(deps));
  }

  String _savedOrEmpty(AppDependencies deps) {
    if (kBaseUrlDefine.isNotEmpty) return '';
    final prefsUrl = deps.prefs.getString(StorageKeys.prefsBaseUrl) ?? '';
    if (prefsUrl.isNotEmpty) return prefsUrl;
    return dotenv.env['BASE_URL']?.trim() ?? '';
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = ref.watch(appDependenciesProvider);
    final effective = deps.effectiveBaseUrl;
    final fromDefine = kBaseUrlDefine.trim().isNotEmpty;
    final fromEnvOnly = !fromDefine &&
        (deps.prefs.getString(StorageKeys.prefsBaseUrl)?.trim().isEmpty ?? true) &&
        (dotenv.env['BASE_URL']?.trim().isNotEmpty ?? false);
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
            subtitle: const Text('최신 버전 여부를 확인합니다.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await AppUpdateService.checkAndUpdateIfNeeded(
                context,
                forceRecheck: true,
                showUpToDateMessage: true,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '연결',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, size: 20, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '서버 주소 (BASE_URL)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fromDefine
                        ? '빌드 시 --dart-define=BASE_URL 로 고정되어 있습니다.'
                        : fromEnvOnly
                            ? '지금은 프로젝트 루트 .env 의 BASE_URL 을 씁니다. 아래에 입력 후 저장하면 기기에 저장되어 .env 보다 우선합니다.'
                            : '끝에 / 를 붙이지 마세요. 예: https://app.example.com',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlCtrl,
                    enabled: !fromDefine,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'BASE_URL',
                      hintText: 'https://배포도메인',
                      prefixIcon: Icon(Icons.language),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      effective.isEmpty ? '현재: (미설정)' : '현재: $effective',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: fromDefine
                        ? null
                        : () async {
                            await deps.setDebugBaseUrl(_urlCtrl.text.trim());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('저장했습니다.')),
                              );
                              setState(() {});
                            }
                          },
                    icon: const Icon(Icons.save_outlined, size: 20),
                    label: const Text('저장'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
