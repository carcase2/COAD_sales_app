import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/launcher_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_detail_screen.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_follow_up_sheet.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/home/home_today_action_list.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final gosuTodayDeskProvider = FutureProvider<List<GosuSalesCall>>((ref) async {
  final today = todayYmdSeoul();
  final repo = ref.read(gosuSalesCallsRepositoryProvider);
  final scheduled = await repo.fetchScheduledForCalendar(
    fromYmd: addDaysToYmd(today, -14),
    toYmdInclusive: today,
  );
  scheduled.sort((a, b) {
    return a.followCalendarDateKey.compareTo(b.followCalendarDateKey);
  });
  return scheduled.where(isGosuCalendarScheduled).toList();
});

class GosuTodayDeskHost extends ConsumerWidget {
  const GosuTodayDeskHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayYmdSeoul();
    final async = ref.watch(gosuTodayDeskProvider);
    final accent = AppTokens.gosuAccent(Theme.of(context).colorScheme);
    return async.when(
      data: (rows) {
        final items = [
          for (final row in rows)
            HomeTodayActionItem(
              id: row.id,
              title: row.displayName,
              reason: () {
                final day = row.followCalendarDateKey;
                if (day.isEmpty || day == today) return '오늘 팔로업';
                return '지난 팔로업 $day';
              }(),
              actionLabel: '팔로업',
              alert: row.followCalendarDateKey.compareTo(today) < 0,
              canCall: looksLikePhoneQuery(row.displayPhone),
            ),
        ];
        return HomeTodayActionList(
          items: items,
          accent: accent,
          emptyMessage: '오늘 팔로업할 건이 없습니다',
          onTapItem: (item) => unawaited(_openDetail(context, ref, item.id)),
          onTapAction: (item) => unawaited(_follow(context, ref, rows, item.id)),
          onTapPhone: (item) {
            final row = rows.where((e) => e.id == item.id).firstOrNull;
            final phone = row?.displayPhone ?? '';
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

Future<void> _openDetail(BuildContext context, WidgetRef ref, String id) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => GosuCallDetailScreen(id: id),
    ),
  );
  ref.invalidate(gosuTodayDeskProvider);
  ref.invalidate(gosuHomeCountsProvider);
}

Future<void> _follow(
  BuildContext context,
  WidgetRef ref,
  List<GosuSalesCall> rows,
  String id,
) async {
  final row = rows.where((e) => e.id == id).firstOrNull;
  if (row == null) return;
  await showGosuFollowUpSheet(context: context, ref: ref, row: row);
  ref.invalidate(gosuTodayDeskProvider);
  ref.invalidate(gosuHomeCountsProvider);
}
