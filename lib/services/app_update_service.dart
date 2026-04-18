import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static bool _alreadyChecked = false;
  static bool _optionalDialogShown = false;

  static Future<void> checkAndUpdateIfNeeded(
    BuildContext context, {
    bool forceRecheck = false,
    bool showUpToDateMessage = false,
    String? preferredStoreUrl,
  }) async {
    if ((!forceRecheck && _alreadyChecked) || kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _alreadyChecked = true;

    try {
      final policy = await _fetchUpdatePolicy();
      if (context.mounted && policy != null) {
        final shouldForce = policy.forceUpdate || _compareVersion(kAppVersion, policy.minVersion) < 0;
        final shouldRecommend = _compareVersion(kAppVersion, policy.latestVersion) < 0;

        if (shouldForce) {
          await _showForceUpdateDialog(
            context,
            policy,
            preferredStoreUrl: preferredStoreUrl,
          );
          return;
        }

        if (shouldRecommend && !_optionalDialogShown) {
          _optionalDialogShown = true;
          await _showOptionalUpdateDialog(
            context,
            policy,
            preferredStoreUrl: preferredStoreUrl,
          );
        }
      }

      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        if (showUpToDateMessage && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('최신 버전(v$kAppVersion)입니다.')),
          );
        }
        return;
      }

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트가 적용되었습니다. 앱을 다시 열어 최신 버전을 사용하세요.')),
        );
      }
    } catch (e) {
      debugPrint('앱 업데이트 체크 실패: $e');
      if (showUpToDateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트 확인에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
        );
      }
    }
  }

  static Future<_UpdatePolicy?> _fetchUpdatePolicy() async {
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('app_update_policy')
          .select('min_version, latest_version, store_url, force_update')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final minVersion = (row['min_version'] ?? '').toString().trim();
      final latestVersion = (row['latest_version'] ?? '').toString().trim();
      if (minVersion.isEmpty || latestVersion.isEmpty) return null;
      return _UpdatePolicy(
        minVersion: minVersion,
        latestVersion: latestVersion,
        storeUrl: (row['store_url'] ?? '').toString().trim(),
        forceUpdate: row['force_update'] == true,
      );
    } catch (e) {
      debugPrint('업데이트 정책 조회 실패(무시): $e');
      return null;
    }
  }

  static int _compareVersion(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static Future<void> _showForceUpdateDialog(
    BuildContext context,
    _UpdatePolicy policy, {
    String? preferredStoreUrl,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('업데이트 필요'),
          content: Text('현재 버전(v$kAppVersion)은 더 이상 지원되지 않습니다.\n최신 버전(v${policy.latestVersion})으로 업데이트해 주세요.'),
          actions: [
            FilledButton(
              onPressed: () async {
                final targetUrl = (preferredStoreUrl ?? '').trim().isNotEmpty
                    ? preferredStoreUrl!.trim()
                    : policy.storeUrl;
                if (targetUrl.isNotEmpty) {
                  await _openStoreUrl(targetUrl);
                } else {
                  await _runInAppUpdateBestEffort();
                }
              },
              child: const Text('지금 업데이트'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showOptionalUpdateDialog(
    BuildContext context,
    _UpdatePolicy policy, {
    String? preferredStoreUrl,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 버전 안내'),
          content: Text('최신 버전(v${policy.latestVersion})이 있습니다.\n업데이트하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final targetUrl = (preferredStoreUrl ?? '').trim().isNotEmpty
                    ? preferredStoreUrl!.trim()
                    : policy.storeUrl;
                if (targetUrl.isNotEmpty) {
                  await _openStoreUrl(targetUrl);
                } else {
                  await _runInAppUpdateBestEffort();
                }
              },
              child: const Text('업데이트'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _runInAppUpdateBestEffort() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('인앱 업데이트 실행 실패: $e');
    }
  }

  static Future<void> _openStoreUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _UpdatePolicy {
  const _UpdatePolicy({
    required this.minVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.forceUpdate,
  });

  final String minVersion;
  final String latestVersion;
  final String storeUrl;
  final bool forceUpdate;
}
