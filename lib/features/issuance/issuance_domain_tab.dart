import 'package:flutter/material.dart';

/// 세금계산서 / 이행증권 전환 탭 — 발급 목록·완료 화면 공통.
class IssuanceDomainTab extends StatelessWidget {
  const IssuanceDomainTab({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final countText = count == null ? '…' : '$count';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : accent,
                  ),
                ),
              ),
              if (count != null || !selected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    countText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
