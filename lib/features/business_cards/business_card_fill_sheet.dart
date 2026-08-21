import 'package:coad_customer_calls/data/business_card_repository.dart';
import 'package:coad_customer_calls/models/business_card.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<BusinessCardFill?> showBusinessCardFillSheet(
  BuildContext context, {
  required List<BusinessCardFill> choices,
}) {
  return showModalBottomSheet<BusinessCardFill>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _BusinessCardFillSheet(choices: choices),
  );
}

/// 번호가 하나면 바로 고르고, 여러 개면 시트로 고른다.
Future<BusinessCardFill?> resolveBusinessCardFill(
  BuildContext context, {
  required String query,
  required List<BusinessCard> found,
}) async {
  final choices = businessCardFillChoices(query, found);
  if (choices.isEmpty) return null;
  if (choices.length == 1) return choices.first;
  if (!context.mounted) return null;
  return showBusinessCardFillSheet(context, choices: choices);
}

class _BusinessCardFillSheet extends StatelessWidget {
  const _BusinessCardFillSheet({required this.choices});

  final List<BusinessCardFill> choices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTokens.customerSupportAccent(scheme);
    final grouped = <String, List<BusinessCardFill>>{};
    for (final item in choices) {
      grouped.putIfAbsent(item.card.id, () => []).add(item);
    }
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '명함에서 고르기',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '전화번호가 여러 개입니다. 쓸 번호를 선택하세요.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in grouped.values) ...[
                  Text(
                    [
                      group.first.card.displayName,
                      if (group.first.card.company.trim().isNotEmpty)
                        group.first.card.company.trim(),
                      if (group.first.card.email.trim().isNotEmpty)
                        group.first.card.email.trim(),
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  for (final item in group)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop(item);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: Row(
                              children: [
                                Icon(Icons.phone_rounded, color: accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.phone.isEmpty
                                        ? '전화번호 없음'
                                        : '${item.phoneLabel}  ${item.phone}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
