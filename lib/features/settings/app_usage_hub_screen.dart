import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/checksheet/checksheet_usage_screen.dart';
import 'package:coad_customer_calls/features/checksheet/install_after_usage_screen.dart';
import 'package:coad_customer_calls/features/quoter/shutter_estimator_log_screen.dart';
import 'package:coad_customer_calls/features/settings/app_usage_screen.dart';
import 'package:coad_customer_calls/features/settings/sales_tool_usage_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 사용량과 기능별 사용 기록을 한 화면의 탭으로 본다.
class AppUsageScreen extends ConsumerWidget {
  const AppUsageScreen({super.key, this.initialTab = tabApp});

  final int initialTab;

  static const tabApp = 0;
  static const tabChecksheet = 1;
  static const tabPhotos = 2;
  static const tabEstimator = 3;
  static const tabCards = 4;
  static const tabQuotes = 5;

  static const labels = ['앱', '체크시트', '시공사진', '견적기', '명함', '표준단가'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    if (!isAdminGroup(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('앱 사용량')),
        body: const AppEmpty(
          message: '관리자 그룹만 조회할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final index = initialTab.clamp(0, labels.length - 1).toInt();

    return DefaultTabController(
      length: labels.length,
      initialIndex: index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('앱 사용량'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: scheme.outlineVariant.withValues(alpha: 0.35),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [for (final label in labels) Tab(text: label)],
          ),
        ),
        body: const TabBarView(
          children: [
            _KeepAlive(child: AppUsageOverview()),
            _KeepAlive(child: ChecksheetUsageScreen(embedded: true)),
            _KeepAlive(child: InstallAfterUsageScreen(embedded: true)),
            _KeepAlive(child: ShutterEstimatorLogScreen(embedded: true)),
            _KeepAlive(
              child: SalesToolUsageScreen(
                embedded: true,
                kind: SalesToolUsageKind.cards,
              ),
            ),
            _KeepAlive(
              child: SalesToolUsageScreen(
                embedded: true,
                kind: SalesToolUsageKind.quotes,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
