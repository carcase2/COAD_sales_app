import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ReceptionKind { afterSales, sales }

Future<ReceptionKind?> showReceptionKindSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<ReceptionKind>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final bottom = MediaQuery.paddingOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '접수 유형',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'A/S와 영업 중 선택해서 등록합니다.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            _ReceptionKindTile(
              title: 'A/S (테스트중)',
              subtitle: '고객지원 · 현장 수리',
              icon: Icons.handyman_outlined,
              accent: AppTokens.customerSupportAccent(scheme),
              onTap: () => Navigator.pop(context, ReceptionKind.afterSales),
            ),
            const SizedBox(height: 8),
            _ReceptionKindTile(
              title: '영업',
              subtitle: '고객전화 · 상담 · 견적',
              icon: Icons.phone_in_talk_outlined,
              accent: AppTokens.receptionAccent(scheme),
              onTap: () => Navigator.pop(context, ReceptionKind.sales),
            ),
          ],
        ),
      );
    },
  );
}

class _ReceptionKindTile extends StatelessWidget {
  const _ReceptionKindTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
