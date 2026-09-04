import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeTodayActionItem {
  const HomeTodayActionItem({
    required this.id,
    required this.title,
    required this.reason,
    required this.actionLabel,
    this.alert = false,
    this.canCall = false,
  });

  final String id;
  final String title;
  final String reason;
  final String actionLabel;
  final bool alert;
  final bool canCall;
}

class HomeTodayActionList extends StatelessWidget {
  const HomeTodayActionList({
    super.key,
    required this.items,
    required this.onTapItem,
    required this.onTapAction,
    this.onTapPhone,
    this.emptyMessage = '오늘 조치할 건이 없습니다',
    this.title = '오늘 조치',
    this.accent,
  });

  final List<HomeTodayActionItem> items;
  final ValueChanged<HomeTodayActionItem> onTapItem;
  final ValueChanged<HomeTodayActionItem> onTapAction;
  final ValueChanged<HomeTodayActionItem>? onTapPhone;
  final String emptyMessage;
  final String title;
  final Color? accent;

  static const previewLimit = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = accent ?? scheme.primary;
    final preview = items.length <= previewLimit
        ? items
        : items.sublist(0, previewLimit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          items.isEmpty ? emptyMessage : title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '접수·팔로우가 생기면 여기에 바로 나옵니다.',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          const SizedBox(height: 6),
          for (final item in preview) ...[
            _Row(
              item: item,
              tone: tone,
              onTap: () => onTapItem(item),
              onAction: () => onTapAction(item),
              onPhone: onTapPhone == null || !item.canCall
                  ? null
                  : () => onTapPhone!(item),
            ),
            const SizedBox(height: 6),
          ],
          if (items.length > previewLimit)
            Text(
              '외 ${items.length - previewLimit}건은 위 숫자 칸에서 봅니다.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.tone,
    required this.onTap,
    required this.onAction,
    this.onPhone,
  });

  final HomeTodayActionItem item;
  final Color tone;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback? onPhone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.alert ? scheme.error : tone;
    return Material(
      color: item.alert
          ? scheme.errorContainer.withValues(alpha: 0.45)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                item.alert
                    ? Icons.phone_missed_rounded
                    : Icons.event_available_rounded,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPhone != null)
                IconButton(
                  tooltip: '전화',
                  visualDensity: VisualDensity.compact,
                  onPressed: onPhone,
                  icon: Icon(
                    Icons.phone_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onAction();
                },
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(item.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
