import 'package:coad_customer_calls/core/config/env.dart';
import 'package:coad_customer_calls/core/constants/storage_keys.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/providers.dart';
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
    return deps.prefs.getString(StorageKeys.prefsBaseUrl) ?? '';
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

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '서버 주소',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            fromDefine
                ? '빌드 시 --dart-define=BASE_URL 로 고정되어 있습니다. 우선순위가 가장 높습니다.'
                : '끝에 / 를 붙이지 마세요. 예: https://app.example.com',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            enabled: !fromDefine,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'BASE_URL',
              hintText: 'https://배포도메인',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('현재 사용 중: ${effective.isEmpty ? "(미설정)" : effective}'),
          const SizedBox(height: 24),
          FilledButton(
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
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
