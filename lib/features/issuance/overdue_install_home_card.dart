import 'package:coad_customer_calls/data/auth_controller.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_list_page.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_provider.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeOverdueInstallCard extends ConsumerWidget {
  const HomeOverdueInstallCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(overduePendingRowsProvider);
    final rows = async.valueOrNull ?? const <OverdueInstallSite>[];
    final count = rows.length;
    final scheme = Theme.of(context).colorScheme;
    final loading = async.isLoading && async.valueOrNull == null;
    final alert = count > 0;
    return Material(
      color: alert
          ? scheme.errorContainer.withValues(alpha: 0.7)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading
            ? null
            : () {
                HapticFeedback.selectionClick();
                showOverdueInstallAssigneeSheet(context: context, rows: rows);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 16,
                color: alert ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '시공완료 안 된 건',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                loading ? '…' : '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: alert ? scheme.error : scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showOverdueInstallAssigneeSheet({
  required BuildContext context,
  required List<OverdueInstallSite> rows,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _OverdueInstallAssigneeSheet(rows: rows),
  );
}

class _OverdueInstallAssigneeSheet extends ConsumerWidget {
  const _OverdueInstallAssigneeSheet({required this.rows});

  final List<OverdueInstallSite> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final userName = ref.watch(authControllerProvider)?.name;
    final counts = <String, int>{'전체': rows.length};
    for (final row in rows) {
      counts[row.assigneeKey] = (counts[row.assigneeKey] ?? 0) + 1;
    }
    final names = overdueInstallAssigneeOrder({
      for (final e in counts.entries)
        if (e.key != '전체') e.key: e.value,
    }, userName);
    final keys = ['전체', ...names];
    final colorCache = <String, Color>{};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '시공완료 안 된 건',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '금일 이전 · 담당자별',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: keys.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, i) {
                  final name = keys[i];
                  final count = counts[name] ?? 0;
                  final mine = overdueInstallIsMine(name, userName);
                  final color = hubAssigneeColor(
                    scheme,
                    name,
                    cache: colorCache,
                    orderedAssignees: names,
                  );
                  return ListTile(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OverdueInstallListPage(
                            initialAssignee: name,
                            initialCalendarView: false,
                            initialAllDates: true,
                          ),
                        ),
                      );
                    },
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      mine ? '나 · $name' : name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: name == '전체' ? scheme.onSurface : color,
                      ),
                    ),
                    trailing: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
