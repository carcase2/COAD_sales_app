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
  ///
  /// `app_update_policy` 최근 rows를 기반으로,
  /// - 버전: `latest_version` (fallback: `min_version`)
  /// - 제안자: `proposed_by` / `proposer` / `requested_by`
  /// - 변경내역: `release_notes` / `changes` / `change_summary`
  /// 를 유연하게 파싱합니다.
  static Future<List<UpdateHistoryEntry>> fetchUpdateHistory({
    int limit = 10,
  }) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('app_update_policy')
          .select()
          .order('updated_at', ascending: false)
          .limit(limit);

      final parsed = <UpdateHistoryEntry>[];
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw);
        final version = (map['latest_version'] ?? map['min_version'] ?? '')
            .toString()
            .trim();
        if (version.isEmpty) continue;

        final dateLabel = _dateOnlyLabel(map['updated_at']);
        final proposer = _firstNonEmptyString([
          map['proposed_by'],
          map['proposer'],
          map['requested_by'],
        ]);
        final changes = _normalizeReleaseNotes(
          map['release_notes'] ?? map['changes'] ?? map['change_summary'],
        );
        parsed.add(
          UpdateHistoryEntry(
            version: version,
            dateLabel: dateLabel.isEmpty ? '-' : dateLabel,
            proposer: proposer.isEmpty ? '미기재' : proposer,
            changes: changes,
          ),
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('업데이트 이력 조회 실패(무시): $e');
      return const [];
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

  static List<String> _normalizeReleaseNotes(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is Map) {
      final items = <String>[];
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        final value = (entry.value ?? '').toString().trim();
        if (value.isEmpty) continue;
        items.add(key.isEmpty ? value : '$key: $value');
      }
      return items;
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*[-•]\s*'), '').trim())
        .where((line) => line.isNotEmpty)
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
  final List<String> changes;
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
