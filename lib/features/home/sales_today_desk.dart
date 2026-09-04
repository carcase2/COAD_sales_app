import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/features/home/home_today_action_list.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_detail_screen.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesDeskItem {
  const SalesDeskItem({
    required this.call,
    required this.uncalled,
  });

  final SalesCall call;
  final bool uncalled;
}

final salesTodayDeskProvider = FutureProvider<List<SalesDeskItem>>((ref) async {
  final today = todayYmdSeoul();
  final receptions = await ref.watch(hubDayReceptionCallsProvider(today).future);
  final follow = await ref.watch(
    calendarFollowRangeProvider((startYmd: today, endYmd: today)).future,
  );
  final loginName = ref.watch(authControllerProvider)?.name.trim();
  final overrides =
      ref.watch(tempManagerOverridesProvider).valueOrNull ?? const [];
  bool mine(SalesCall c) {
    if (loginName == null || loginName.isEmpty) return true;
    return displayAssigneeForCall(c, overrides, DateTime.now()) == loginName;
  }

  final seen = <String>{};
  final items = <SalesDeskItem>[];
  for (final c in receptions.where((e) => e.isMissed && mine(e))) {
    if (!seen.add(c.id)) continue;
    items.add(SalesDeskItem(call: c, uncalled: true));
  }
  for (final c in follow.where(mine)) {
    if (!seen.add(c.id)) continue;
    items.add(SalesDeskItem(call: c, uncalled: false));
  }
  return items;
});

class SalesTodayDeskHost extends ConsumerWidget {
  const SalesTodayDeskHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesTodayDeskProvider);
    return async.when(
      data: (rows) {
        final items = [
          for (final row in rows)
            HomeTodayActionItem(
              id: row.call.id,
              title: (row.call.customerName ?? '').trim().isEmpty
                  ? '(이름 없음)'
                  : row.call.customerName!.trim(),
              reason: row.uncalled ? '오늘 접수 · 미통화' : '오늘 팔로우',
              actionLabel: '상담',
              alert: row.uncalled,
              canCall: looksLikePhoneQuery(row.call.customerPhone ?? ''),
            ),
        ];
        return HomeTodayActionList(
          items: items,
          onTapItem: (item) => unawaited(_open(context, ref, item.id)),
          onTapAction: (item) =>
              unawaited(_open(context, ref, item.id, consult: true)),
          onTapPhone: (item) {
            final call = rows
                .where((e) => e.call.id == item.id)
                .map((e) => e.call)
                .firstOrNull;
            final phone = call?.customerPhone ?? '';
            if (phone.trim().isEmpty) return;
            unawaited(LauncherUtils.makePhoneCall(phone));
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

Future<void> _open(
  BuildContext context,
  WidgetRef ref,
  String id, {
  bool consult = false,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => SalesCallDetailScreen(
        id: id,
        openConsultation: consult,
      ),
    ),
  );
  ref.invalidate(salesTodayDeskProvider);
  ref.invalidate(hubDayReceptionCallsProvider);
}
