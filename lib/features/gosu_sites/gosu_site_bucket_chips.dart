import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';

Color gosuBucketColor(ColorScheme scheme, GosuSiteBucket b) => switch (b) {
  GosuSiteBucket.receiving => AppTokens.gosuAccent(scheme),
  GosuSiteBucket.accepted => scheme.tertiary,
  GosuSiteBucket.canceled => scheme.error,
};

Map<GosuSiteBucket, int> gosuBucketCounts(Iterable<GosuSiteBucket> buckets) {
  final m = {for (final b in GosuSiteBucket.values) b: 0};
  for (final b in buckets) {
    m[b] = m[b]! + 1;
  }
  return m;
}

Map<GosuSiteBucket, int> gosuSiteBucketCounts(Iterable<GosuSite> sites) =>
    gosuBucketCounts(sites.map(gosuSiteBucket));

/// 전체 · 접수중 · 접수완료 · 접수취소 건수 칩. [selected] 가 null 이면 전체.
class GosuSiteBucketChips extends StatelessWidget {
  const GosuSiteBucketChips({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
    this.labelOf = gosuSiteBucketLabel,
  });

  final Map<GosuSiteBucket, int> counts;
  final GosuSiteBucket? selected;
  final ValueChanged<GosuSiteBucket?> onSelected;
  final String Function(GosuSiteBucket) labelOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    Widget chip(String label, bool on, Color color, VoidCallback onTap) =>
        ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: on ? Colors.white : color,
          ),
          selectedColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          onSelected: (_) => onTap(),
        );

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(
          '전체 $total',
          selected == null,
          scheme.onSurfaceVariant,
          () => onSelected(null),
        ),
        for (final b in GosuSiteBucket.values)
          chip(
            '${labelOf(b)} ${counts[b] ?? 0}',
            selected == b,
            gosuBucketColor(scheme, b),
            () => onSelected(selected == b ? null : b),
          ),
      ],
    );
  }
}

/// 목록 안 구분 머리글 — "● 접수중 4  통화로 방문일을 잡아야 하는 건".
class GosuBucketHeader extends StatelessWidget {
  const GosuBucketHeader({
    super.key,
    required this.bucket,
    required this.count,
    this.labelOf = gosuSiteBucketLabel,
  });

  final GosuSiteBucket bucket;
  final int count;
  final String Function(GosuSiteBucket) labelOf;

  static String hintOf(GosuSiteBucket b) => switch (b) {
    GosuSiteBucket.receiving => '통화로 방문일을 잡아야 하는 건',
    GosuSiteBucket.accepted => '방문일 입력 이후 진행 중',
    GosuSiteBucket.canceled => '취소·종료',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = gosuBucketColor(scheme, bucket);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${labelOf(bucket)} $count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintOf(bucket),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
