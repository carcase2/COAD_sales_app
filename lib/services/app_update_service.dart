import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play 인앱 업데이트 — **설치는 Play가 전담**하도록 즉시 업데이트·스토어 이동만 사용합니다.
///
/// 유연(flexible) 업데이트는 앱 안에서 `completeFlexibleUpdate()`로 설치를 마무리할 때
/// 실패·멈춤이 잦아 사용하지 않습니다.
class AppUpdateService {
  static const String _playPackageId = 'com.coad.customer_calls';

  static bool _alreadyChecked = false;
  static bool _optionalDialogShown = false;
  static DateTime? _lastInUsePromptAt;
  static const Duration _inUsePromptCooldown = Duration(hours: 4);

  /// Supabase `app_update_policy` 기준으로 업데이트 필요 여부만 조회 (UI 배지·배너용).
  static Future<AppUpdateStatus> fetchUpdateStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const AppUpdateStatus();
    }
    try {
      final policy = await _fetchUpdatePolicy();
      if (policy == null) return const AppUpdateStatus();
      final shouldForce = policy.forceUpdate ||
          _compareVersion(kAppVersion, policy.minVersion) < 0;
      final shouldRecommend =
          _compareVersion(kAppVersion, policy.latestVersion) < 0;
      return AppUpdateStatus(
        hasUpdate: shouldForce || shouldRecommend,
        forceUpdate: shouldForce,
        latestVersion: policy.latestVersion,
        storeUrl: policy.storeUrl,
      );
    } catch (e) {
      debugPrint('업데이트 상태 조회 실패: $e');
      return const AppUpdateStatus();
    }
  }

  /// 앱 사용 중(다시 foreground 등) 주기적으로 정책을 확인하고 안내합니다.
  static Future<void> checkWhileInUse(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final policy = await _fetchUpdatePolicy();
      if (policy == null || !context.mounted) return;

      final shouldForce = policy.forceUpdate ||
          _compareVersion(kAppVersion, policy.minVersion) < 0;
      final shouldRecommend =
          _compareVersion(kAppVersion, policy.latestVersion) < 0;

      if (shouldForce) {
        await _showForceUpdateDialog(context, policy);
        return;
      }

      if (!shouldRecommend) return;

      final now = DateTime.now();
      final cooldownOk = _lastInUsePromptAt == null ||
          now.difference(_lastInUsePromptAt!) >= _inUsePromptCooldown;
      if (!cooldownOk) return;

      _lastInUsePromptAt = now;
      await _showOptionalUpdateDialog(context, policy);
    } catch (e) {
      debugPrint('사용 중 업데이트 체크 실패: $e');
    }
  }

  /// [showUpToDateMessage]가 true이면 설정·푸시 등 사용자가 직접 누른 경우로,
  /// Play 즉시 업데이트 → Play 스토어 앱 페이지 순으로 시도합니다.
  static Future<void> checkAndUpdateIfNeeded(
    BuildContext context, {
    bool forceRecheck = false,
    bool showUpToDateMessage = false,
    String? preferredStoreUrl,
  }) async {
    if ((!forceRecheck && _alreadyChecked) ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (forceRecheck) {
      _optionalDialogShown = false;
    }
    if (!showUpToDateMessage) {
      _alreadyChecked = true;
    }

    try {
      final policy = await _fetchUpdatePolicy();
      final shouldForce = policy != null &&
          (policy.forceUpdate ||
              _compareVersion(kAppVersion, policy.minVersion) < 0);
      final shouldRecommend = policy != null &&
          _compareVersion(kAppVersion, policy.latestVersion) < 0;

      if (context.mounted && shouldForce) {
        await _showForceUpdateDialog(
          context,
          policy!,
          preferredStoreUrl: preferredStoreUrl,
        );
        return;
      }

      if (showUpToDateMessage) {
        await _runUserInitiatedUpdate(
          context,
          policy: policy,
          shouldRecommend: shouldRecommend,
          preferredStoreUrl: preferredStoreUrl,
        );
        return;
      }

      if (context.mounted &&
          policy != null &&
          shouldRecommend &&
          !_optionalDialogShown) {
        _optionalDialogShown = true;
        await _showOptionalUpdateDialog(
          context,
          policy,
          preferredStoreUrl: preferredStoreUrl,
        );
      }

      await _tryImmediateInAppUpdate();
    } catch (e) {
      debugPrint('앱 업데이트 체크 실패: $e');
      if (showUpToDateMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업데이트 확인에 실패했습니다. 잠시 후 다시 시도해 주세요.'),
          ),
        );
      }
    }
  }

  /// 설정 > 업데이트 확인: 즉시 업데이트 불가 시 Play 스토어에서 설치.
  static Future<void> _runUserInitiatedUpdate(
    BuildContext context, {
    required _UpdatePolicy? policy,
    required bool shouldRecommend,
    String? preferredStoreUrl,
  }) async {
    if (!context.mounted) return;

    final applied = await _tryImmediateInAppUpdate();
    if (applied) return;

    await _openStoreForInstall(
      context,
      policy: policy,
      preferredStoreUrl: preferredStoreUrl,
    );

    if (!context.mounted) return;

    if (shouldRecommend && policy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Play 스토어에서 [업데이트]를 눌러 v${policy.latestVersion}을 설치해 주세요. (현재 v$kAppVersion)',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Play 스토어에서 [업데이트]로 설치해 주세요. (현재 v$kAppVersion)',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  static String _resolveStoreUrl({
    required _UpdatePolicy? policy,
    String? preferredStoreUrl,
  }) {
    final preferred = (preferredStoreUrl ?? '').trim();
    if (preferred.isNotEmpty) return preferred;
    return policy?.storeUrl ?? '';
  }

  static Future<void> _openStoreForInstall(
    BuildContext context, {
    required _UpdatePolicy? policy,
    String? preferredStoreUrl,
  }) async {
    final targetUrl = _resolveStoreUrl(
      policy: policy,
      preferredStoreUrl: preferredStoreUrl,
    );
    if (targetUrl.isNotEmpty) {
      await _openStoreUrl(targetUrl);
    } else {
      await _openPlayStoreListing();
    }
  }

  static Future<void> _fallbackToStoreOrNotify(
    BuildContext context, {
    required _UpdatePolicy policy,
    String? preferredStoreUrl,
  }) async {
    if (!context.mounted) return;

    await _openStoreForInstall(
      context,
      policy: policy,
      preferredStoreUrl: preferredStoreUrl,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Play 스토어에서 [업데이트]를 눌러 v${policy.latestVersion}을 설치해 주세요. (현재 v$kAppVersion)',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  static Future<_UpdatePolicy?> _fetchUpdatePolicy() async {
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('app_update_policy')
          .select('min_version, latest_version, store_url, force_update')
          .eq('is_active', true)
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

  /// 설정 화면용 업데이트 이력 조회.
  /// `app_update_history` 최신 row를 created_at DESC 기준으로 조회합니다.
  static Future<List<UpdateHistoryEntry>> fetchUpdateHistory({
    int limit = 10,
  }) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('app_update_history')
          .select('version, proposer, release_notes, created_at')
          .eq('is_visible', true)
          .order('created_at', ascending: false)
          .limit(limit);

      final parsed = <UpdateHistoryEntry>[];
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        final version = (map['version'] ?? '')
            .toString()
            .trim();
        if (version.isEmpty) continue;

        final dateLabel = _dateOnlyLabel(map['created_at']);
        final proposer = _firstNonEmptyString([map['proposer']]);
        final fallbackProposer = proposer.isEmpty ? '미기재' : proposer;
        final changes = _normalizeReleaseNotes(
          map['release_notes'],
          fallbackProposer: fallbackProposer,
        );
        parsed.add(
          UpdateHistoryEntry(
            version: version,
            dateLabel: dateLabel.isEmpty ? '-' : dateLabel,
            proposer: fallbackProposer,
            changes: changes,
          ),
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('업데이트 이력 조회 실패: $e');
      throw Exception('업데이트 내역 조회 실패');
    }
  }

  static String _dateOnlyLabel(dynamic raw) {
    final src = (raw ?? '').toString().trim();
    if (src.isEmpty) return '';
    final parsed = DateTime.tryParse(src);
    if (parsed == null) {
      return src.length >= 10 ? src.substring(0, 10) : src;
    }
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _firstNonEmptyString(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static List<UpdateHistoryChangeItem> _normalizeReleaseNotes(
    dynamic raw, {
    required String fallbackProposer,
  }) {
    if (raw == null) return const [];

    String resolveProposer(Map<dynamic, dynamic> map) {
      final fromItem = _firstNonEmptyString([
        map['proposer'],
        map['proposed_by'],
        map['requested_by'],
      ]);
      return fromItem.isEmpty ? fallbackProposer : fromItem;
    }

    if (raw is List) {
      final items = <UpdateHistoryChangeItem>[];
      for (final entry in raw) {
        if (entry is Map) {
          final map = Map<dynamic, dynamic>.from(entry);
          final text = _firstNonEmptyString([
            map['note'],
            map['text'],
            map['change'],
            map['summary'],
          ]);
          if (text.isEmpty) continue;
          items.add(
            UpdateHistoryChangeItem(
              text: text,
              proposer: resolveProposer(map),
            ),
          );
          continue;
        }
        final text = (entry ?? '').toString().trim();
        if (text.isEmpty) continue;
        items.add(
          UpdateHistoryChangeItem(text: text, proposer: fallbackProposer),
        );
      }
      return items;
    }
    if (raw is Map) {
      final items = <UpdateHistoryChangeItem>[];
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final value = (entry.value ?? '').toString().trim();
        if (value.isEmpty) continue;
        items.add(
          UpdateHistoryChangeItem(
            text: key.isEmpty ? value : '$key: $value',
            proposer: fallbackProposer,
          ),
        );
      }
      return items;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*[-•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => UpdateHistoryChangeItem(
            text: line,
            proposer: fallbackProposer,
          ),
        )
        .toList();
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
          content: Text(
            '현재 버전(v$kAppVersion)은 더 이상 지원되지 않습니다.\n'
            'Play 스토어에서 v${policy.latestVersion}을 설치해 주세요.',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runUpdateWithStoreFallback(
                  context,
                  policy: policy,
                  preferredStoreUrl: preferredStoreUrl,
                );
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
          content: Text(
            '최신 버전(v${policy.latestVersion})이 있습니다.\n'
            '업데이트하시겠어요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _runUpdateWithStoreFallback(
                  context,
                  policy: policy,
                  preferredStoreUrl: preferredStoreUrl,
                );
              },
              child: const Text('업데이트'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _runUpdateWithStoreFallback(
    BuildContext context, {
    required _UpdatePolicy policy,
    String? preferredStoreUrl,
  }) async {
    final applied = await _tryImmediateInAppUpdate();
    if (applied) return;
    await _fallbackToStoreOrNotify(
      context,
      policy: policy,
      preferredStoreUrl: preferredStoreUrl,
    );
  }

  /// Play 전체 화면 **즉시** 업데이트만 시도. 설치 단계는 Play API가 처리합니다.
  ///
  /// 유연 업데이트·앱 내 `completeFlexibleUpdate()`는 설치 실패가 잦아 사용하지 않습니다.
  /// 백그라운드 다운로드만 끝난 상태면 false를 반환하고 스토어 설치로 넘깁니다.
  static Future<bool> _tryImmediateInAppUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint(
        'InAppUpdate: availability=${info.updateAvailability}, '
        'status=${info.installStatus}, immediate=${info.immediateUpdateAllowed}, '
        'flexible=${info.flexibleUpdateAllowed}',
      );

      if (info.installStatus == InstallStatus.downloaded ||
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress) {
        debugPrint(
          'InAppUpdate: pending flexible install — open Play Store instead',
        );
        return false;
      }

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }

      if (!info.immediateUpdateAllowed) {
        debugPrint('InAppUpdate: immediate not allowed, use Play Store');
        return false;
      }

      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.success) return true;
      debugPrint('InAppUpdate immediate result: $result');
    } catch (e) {
      debugPrint('인앱 업데이트 실행 실패: $e');
    }
    return false;
  }

  static Future<bool> _openPlayStoreListing() async {
    final marketUri = Uri.parse('market://details?id=$_playPackageId');
    if (await canLaunchUrl(marketUri)) {
      return launchUrl(marketUri);
    }
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_playPackageId',
    );
    if (await canLaunchUrl(webUri)) {
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<void> _openStoreUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// 설정·메인 화면 배지용 업데이트 상태.
class AppUpdateStatus {
  const AppUpdateStatus({
    this.hasUpdate = false,
    this.forceUpdate = false,
    this.latestVersion,
    this.storeUrl,
  });

  final bool hasUpdate;
  final bool forceUpdate;
  final String? latestVersion;
  final String? storeUrl;

  bool get isUpToDate => !hasUpdate;
}

class UpdateHistoryChangeItem {
  const UpdateHistoryChangeItem({
    required this.text,
    required this.proposer,
  });

  final String text;
  final String proposer;
}

class UpdateHistoryEntry {
  const UpdateHistoryEntry({
    required this.version,
    required this.dateLabel,
    required this.proposer,
    required this.changes,
  });

  final String version;
  final String dateLabel;
  final String proposer;
  final List<UpdateHistoryChangeItem> changes;

  bool get hasPerItemProposer =>
      changes.isNotEmpty &&
      changes.any((change) => change.proposer != proposer);
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
