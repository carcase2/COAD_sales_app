import 'dart:async';

import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_search_screen.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_usage_screen.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/quoter/shutter_estimator_log_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:coad_customer_calls/features/settings/app_usage_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/providers/app_update_provider.dart';
import 'package:coad_customer_calls/providers/theme_mode_provider.dart';
import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _flowUncalledPopupEnabled;
  late bool _notifyNewCall;
  late bool _notifyIssuance;
  late bool _notifyGeneralSchedule;
  late bool _notifyDaeguSchedule;
  late bool _notifyAsDue;
  int _updateHistoryReloadToken = 0;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(appDependenciesProvider).prefs;
    _notifyNewCall =
        prefs.getBool(NotificationService.prefKeyNotifyNewCall) ?? true;
    _notifyIssuance =
        prefs.getBool(NotificationService.prefKeyNotifyIssuance) ?? true;
    _notifyGeneralSchedule =
        prefs.getBool(NotificationService.prefKeyNotifyGeneralSchedule) ?? true;
    _notifyDaeguSchedule =
        prefs.getBool(NotificationService.prefKeyNotifyDaeguSchedule) ?? true;
    _notifyAsDue =
        prefs.getBool(NotificationService.prefKeyNotifyAsDue) ?? true;
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

  Future<void> _setNotifyPref(String key, bool enabled) async {
    final prefs = ref.read(appDependenciesProvider).prefs;
    await prefs.setBool(key, enabled);
  }

  Widget _buildNotifyToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12.5,
          color: scheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updateStatus = ref.watch(appUpdateStatusProvider).valueOrNull;
    final user = ref.watch(authControllerProvider);
    final loginName = user?.name.trim();
    final flowPopupOn = _flowUncalledPopupEnabled ?? true;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (user != null) ...[
            Text(
              '계정',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  (loginName != null && loginName.isNotEmpty)
                      ? loginName[0]
                      : '?',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                loginName != null && loginName.isNotEmpty ? loginName : '사용자',
              ),
              subtitle: Text('사번/ID: ${user.id}'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                '로그아웃',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
          if (user != null && isAppAdmin(user)) ...[
            Text(
              '관리',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bar_chart_rounded, color: scheme.primary),
              title: const Text('앱 사용량'),
              subtitle: const Text('앱을 실제로 사용한 직원 통계'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppUsageScreen(),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_edu_rounded, color: scheme.primary),
              title: const Text('견적기 사용 이력'),
              subtitle: const Text('셔터 견적기 사용 통계 · 상세 이력'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ShutterEstimatorLogScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          Text(
            '자료',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (canViewStandardUnitPrice(ref.watch(authControllerProvider)))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.grid_on_rounded, color: scheme.primary),
              title: const Text('사이즈 표준단가(테스트중)'),
              subtitle: const Text('폭×높이·모델별 표준단가 조회'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StandardUnitPriceScreen(),
                  ),
                );
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fact_check_outlined, color: scheme.primary),
            title: const Text('체크시트 검색'),
            subtitle: const Text('MES 아카이브 · 체크시트(TP1)만'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChecksheetSearchScreen(),
                ),
              );
            },
          ),
          if (isAppAdmin(user))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bar_chart_rounded, color: scheme.primary),
              title: const Text('체크시트 사용 내역'),
              subtitle: const Text('사용자별 검색·열람·저장 순위'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChecksheetUsageScreen(),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
          Text(
            '앱',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline, color: scheme.primary),
            title: const Text('앱 버전'),
            subtitle: Text('v$kAppVersion'),
          ),
          const SizedBox(height: 4),
          Text(
            '화면 모드',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('밝게'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('어둡게'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('시스템'),
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              ref.read(themeModeProvider.notifier).setMode(selected.first);
            },
          ),
          const SizedBox(height: 6),
          Text(
            themeMode == ThemeMode.light
                ? '기본값입니다. 항상 밝은 화면으로 표시합니다.'
                : themeMode == ThemeMode.dark
                ? '항상 어두운 화면으로 표시합니다.'
                : '휴대폰 다크 모드 설정을 따릅니다.',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.system_update_alt_rounded,
              color: scheme.primary,
            ),
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
            '알림',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _buildNotifyToggle(
            title: '새 접수 알림',
            subtitle: '새 통화 접수가 등록되면 알림을 받습니다.',
            value: _notifyNewCall,
            onChanged: (v) {
              setState(() => _notifyNewCall = v);
              _setNotifyPref(NotificationService.prefKeyNotifyNewCall, v);
            },
          ),
          _buildNotifyToggle(
            title: '발급요청 알림',
            subtitle: '세금계산서·이행증권 발급 요청/완료 알림을 받습니다.',
            value: _notifyIssuance,
            onChanged: (v) {
              setState(() => _notifyIssuance = v);
              _setNotifyPref(NotificationService.prefKeyNotifyIssuance, v);
            },
          ),
          _buildNotifyToggle(
            title: '본사일반 일정 알림',
            subtitle: '본사일반 일정 등록·변경 알림을 받습니다.',
            value: _notifyGeneralSchedule,
            onChanged: (v) {
              setState(() => _notifyGeneralSchedule = v);
              _setNotifyPref(
                NotificationService.prefKeyNotifyGeneralSchedule,
                v,
              );
            },
          ),
          _buildNotifyToggle(
            title: '대구지사 일정 알림',
            subtitle: '대구지사 일정 등록·변경 알림을 받습니다.',
            value: _notifyDaeguSchedule,
            onChanged: (v) {
              setState(() => _notifyDaeguSchedule = v);
              _setNotifyPref(NotificationService.prefKeyNotifyDaeguSchedule, v);
            },
          ),
          if (canAccessCustomerSupport(user))
            _buildNotifyToggle(
              title: 'A/S 방문·발송 예정 알림',
              subtitle: '매일 오전 9시, 오후 1시, 오후 6시에 오늘·지난 일정을 알려줍니다.',
              value: _notifyAsDue,
              onChanged: (v) {
                setState(() => _notifyAsDue = v);
                unawaited(() async {
                  await _setNotifyPref(
                    NotificationService.prefKeyNotifyAsDue,
                    v,
                  );
                  await refreshSupportDueReminders(ref);
                }());
              },
            ),
          const SizedBox(height: 16),
          Text(
            '흐름',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '업데이트 내역',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: () => setState(() => _updateHistoryReloadToken++),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<UpdateHistoryEntry>>(
            key: ValueKey(_updateHistoryReloadToken),
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
                          style: TextStyle(fontSize: 12.5, color: scheme.error),
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
                Icon(
                  Icons.new_releases_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
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
