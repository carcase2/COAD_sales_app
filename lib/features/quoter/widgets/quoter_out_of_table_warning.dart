import 'package:flutter/material.dart';

/// 격자 테이블 범위(2000–8000mm)를 벗어난 규격 안내.
class QuoterOutOfTableWarning extends StatelessWidget {
  const QuoterOutOfTableWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.6),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.priority_high_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '테이블 사이즈를 벗어났습니다. 별도로 문의하세요.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: scheme.onErrorContainer,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 범위 밖 견적 금액 바로 아래 — 어느 축을 몇 mm로 계산했는지.
class QuoterOutOfTableAmountNote extends StatelessWidget {
  const QuoterOutOfTableAmountNote({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
