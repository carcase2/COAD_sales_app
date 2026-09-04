import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_screen.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupportIssuancePage extends StatelessWidget {
  const SupportIssuancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('세금계산서')),
      body: const IssuanceRequestScreen(),
    );
  }
}

void showSupportSkeletonSnack(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature은(는) 다음 작업에서 연결합니다.')));
}

/// 견적서 발송일. 오늘 / 예정일 / 다른 날짜.
Future<String?> askSupportQuoteSentYmd(
  BuildContext context, {
  String? plannedYmd,
}) {
  return askSupportMarkedYmd(
    context,
    title: '견적서 발송일',
    hint: '예정일이 아니어도 오늘이나 다른 날로 체크할 수 있습니다',
    todayLabel: '오늘 발송',
    plannedLabel: '예정일에 발송',
    plannedYmd: plannedYmd,
  );
}

/// 실제 입금일. 예정일과 달라도 된다.
Future<String?> askSupportDepositPaidYmd(
  BuildContext context, {
  String? plannedYmd,
}) {
  return askSupportMarkedYmd(
    context,
    title: '입금일',
    hint: '입금예정일과 다른 날에 들어와도 됩니다',
    todayLabel: '오늘 입금',
    plannedLabel: '예정일에 입금',
    plannedYmd: plannedYmd,
  );
}

Future<String?> askSupportMarkedYmd(
  BuildContext context, {
  required String title,
  required String hint,
  required String todayLabel,
  required String plannedLabel,
  String? plannedYmd,
}) async {
  final today = todayYmdSeoul();
  final planned = (plannedYmd ?? '').trim();
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(hint),
              ),
              ListTile(
                leading: const Icon(Icons.today_rounded),
                title: Text(todayLabel),
                subtitle: Text(today),
                onTap: () => Navigator.pop(ctx, today),
              ),
              if (planned.isNotEmpty && planned != today)
                ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(plannedLabel),
                  subtitle: Text(planned),
                  onTap: () => Navigator.pop(ctx, planned),
                ),
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('다른 날짜'),
                onTap: () async {
                  final initial =
                      DateTime.tryParse(planned.isEmpty ? today : planned) ??
                      DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: initial,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked == null || !ctx.mounted) return;
                  final ymd =
                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  Navigator.pop(ctx, ymd);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<SupportVisitReport?> nextSupportDepositPaidReport(
  BuildContext context, {
  required SupportVisitReport report,
  required bool currentlyPaid,
  String? plannedYmd,
}) async {
  if (currentlyPaid) {
    return report.copyWith(depositPaid: false);
  }
  final ymd = await askSupportDepositPaidYmd(
    context,
    plannedYmd: plannedYmd ?? report.depositYmd,
  );
  if (ymd == null) return null;
  return report.copyWith(depositPaid: true, depositPaidYmd: ymd);
}

class SupportSectionCard extends StatelessWidget {
  const SupportSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.badge,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final fg = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap?.call();
              }
            : () => showSupportSkeletonSnack(context, title),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 허브 상단 건수 요약. 큰 타일 대신 한 줄 바로 쓴다.
class SupportHubCountBar extends StatelessWidget {
  const SupportHubCountBar({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.count = 0,
    this.alert = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = alert
        ? scheme.error
        : AppTokens.customerSupportAccent(scheme);
    return Material(
      color: alert
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportHubTile extends StatelessWidget {
  const SupportHubTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.count,
    this.alert = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = alert
        ? scheme.error
        : AppTokens.customerSupportAccent(scheme);
    return Material(
      color: alert
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const Spacer(),
                  if (count != null)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: accent,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupportComingSoonBanner extends StatelessWidget {
  const SupportComingSoonBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message ?? '흐름 확인용 화면입니다. 저장·연동은 다음 작업에서 붙입니다.',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.35,
          color: scheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class SupportExcelButton extends StatelessWidget {
  const SupportExcelButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '엑셀 저장 (다음 작업)',
      onPressed: () => showSupportSkeletonSnack(context, '엑셀 다운로드'),
      icon: const Icon(Icons.table_view_outlined),
    );
  }
}

const kSupportStatusTabOrder = ['전체', '미처리', '대기', '방문예정', '완료'];

Color supportStatusTabColor(String tab, ColorScheme scheme) {
  switch (tab) {
    case '미처리':
      return scheme.error;
    case '방문예정':
      return scheme.tertiary;
    case '완료':
      return AppTokens.success(scheme);
    case '대기':
    case '답 대기·견적서':
    case '진행중':
      return scheme.primary;
    default:
      return AppTokens.customerSupportAccent(scheme);
  }
}

/// 전체 · 미처리 · 진행중 · 방문예정 · 완료
class SupportStatusFilterBar extends StatelessWidget {
  const SupportStatusFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
    this.hideCompleted = false,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;
  final bool hideCompleted;

  @override
  Widget build(BuildContext context) {
    final tabs = hideCompleted
        ? kSupportStatusTabOrder.where((t) => t != '완료').toList()
        : kSupportStatusTabOrder;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final scheme = Theme.of(context).colorScheme;
          final accent = supportStatusTabColor(tab, scheme);
          final selectedChip = selected == tab;
          final count = counts[tab] ?? 0;
          return Material(
            color: selectedChip ? accent : accent.withValues(alpha: 0.14),
            shape: StadiumBorder(
              side: BorderSide(
                color: accent.withValues(alpha: selectedChip ? 0 : 0.45),
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(tab);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    count > 0 && tab != '전체' ? '$tab $count' : tab,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: selectedChip ? Colors.white : accent,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 전체 · 본사 · 대구 · 대전 · 전남 · 기타 — 한 줄 가로 스크롤.
class SupportBranchFilterBar extends StatelessWidget {
  const SupportBranchFilterBar({
    super.key,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: kSupportBranchTabOrder.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final tab = kSupportBranchTabOrder[i];
          return _SupportBranchChip(
            tab: tab,
            count: counts[tab] ?? 0,
            selected: selected == tab,
            onTap: () => onSelected(tab),
          );
        },
      ),
    );
  }
}

class _SupportBranchChip extends StatelessWidget {
  const _SupportBranchChip({
    required this.tab,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String tab;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.supportBranchAccent(tab, scheme);
    final fg = selected ? Colors.white : accent;
    return Material(
      color: selected ? accent : accent.withValues(alpha: 0.14),
      shape: StadiumBorder(
        side: BorderSide(color: accent.withValues(alpha: selected ? 0 : 0.45)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: const Alignment(0, -0.18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: selected ? Colors.white : fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
