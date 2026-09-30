import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/features/settings/usage_embed_frame.dart';
import 'package:coad_customer_calls/models/sales_tool_usage.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum SalesToolUsageKind { cards, quotes }

class _UsageSpan {
  const _UsageSpan({
    required this.id,
    required this.menuLabel,
    required this.shortLabel,
    required this.startYmd,
    required this.endYmd,
  });

  final String id;
  final String menuLabel;
  final String shortLabel;
  final String? startYmd;
  final String endYmd;

  static const ids = ['today', '7', '30', '90', 'all'];

  static _UsageSpan resolve(String id) {
    final today = todayYmdSeoul();
    return switch (id) {
      'today' => _UsageSpan(
        id: id,
        menuLabel: '금일',
        shortLabel: '금일',
        startYmd: today,
        endYmd: today,
      ),
      '7' => _UsageSpan(
        id: id,
        menuLabel: '최근 7일',
        shortLabel: '7일',
        startYmd: addDaysToYmd(today, -6),
        endYmd: today,
      ),
      '90' => _UsageSpan(
        id: id,
        menuLabel: '최근 90일',
        shortLabel: '90일',
        startYmd: addDaysToYmd(today, -89),
        endYmd: today,
      ),
      'all' => _UsageSpan(
        id: id,
        menuLabel: '전체',
        shortLabel: '전체',
        startYmd: null,
        endYmd: today,
      ),
      _ => _UsageSpan(
        id: '30',
        menuLabel: '최근 30일',
        shortLabel: '30일',
        startYmd: addDaysToYmd(today, -29),
        endYmd: today,
      ),
    };
  }
}

/// 명함 등록과 표준단가 견적 작성. 관리자 그룹만.
class SalesToolUsageScreen extends ConsumerStatefulWidget {
  const SalesToolUsageScreen({super.key, this.embedded = false, this.kind});

  final bool embedded;

  /// 지정하면 그 종류만 보여주고 종류 전환은 숨긴다.
  final SalesToolUsageKind? kind;

  @override
  ConsumerState<SalesToolUsageScreen> createState() =>
      _SalesToolUsageScreenState();
}

class _SalesToolUsageScreenState extends ConsumerState<SalesToolUsageScreen> {
  String _spanId = '30';
  SalesToolUsageKind _kind = SalesToolUsageKind.cards;
  bool _excludeAdmins = false;
  AsyncValue<SalesToolUsageBundle> _data = const AsyncLoading();

  final _won = NumberFormat('#,###');

  _UsageSpan get _span => _UsageSpan.resolve(_spanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() => _data = const AsyncLoading());
    try {
      final span = _UsageSpan.resolve(_spanId);
      final bundle = await ref
          .read(usageRepositoryProvider)
          .fetchSalesToolUsage(startYmd: span.startYmd, endYmd: span.endYmd);
      if (!mounted) return;
      setState(() => _data = AsyncData(bundle));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _data = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final kind = widget.kind ?? _kind;
    final cardsMode = kind == SalesToolUsageKind.cards;
    final accent = cardsMode ? scheme.primary : scheme.tertiary;
    final title = cardsMode ? '명함 사용량' : '표준단가 견적 사용량';

    if (!isAdminGroup(user)) {
      return UsageEmbedFrame(
        embedded: widget.embedded,
        title: title,
        body: const AppEmpty(
          message: '관리자 그룹만 조회할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return UsageEmbedFrame(
      embedded: widget.embedded,
      title: widget.kind == null ? '명함·견적 사용량' : title,
      actions: [
        PopupMenuButton<String>(
          tooltip: '기간',
          initialValue: _spanId,
          onSelected: (id) {
            if (id == _spanId) return;
            setState(() => _spanId = id);
            unawaited(_load());
          },
          itemBuilder: (context) => [
            for (final id in _UsageSpan.ids)
              PopupMenuItem(
                value: id,
                child: Text(_UsageSpan.resolve(id).menuLabel),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _span.shortLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: '새로고침',
          onPressed: () {
            HapticFeedback.selectionClick();
            unawaited(_load());
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        children: [
          if (widget.kind == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<SalesToolUsageKind>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: SalesToolUsageKind.cards,
                    label: Text('명함', maxLines: 1),
                  ),
                  ButtonSegment(
                    value: SalesToolUsageKind.quotes,
                    label: Text('표준단가 견적', maxLines: 1),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (next) {
                  HapticFeedback.selectionClick();
                  setState(() => _kind = next.first);
                },
              ),
            ),
          Expanded(
            child: _data.when(
              loading: () => const AppLoading(message: '사용량 불러오는 중…'),
              error: (e, _) => AppErrorState(
                message: koreanErrorMessage(e),
                onRetry: () => unawaited(_load()),
              ),
              data: (bundle) => _Body(
                span: _span,
                kind: kind,
                accent: accent,
                report: cardsMode ? bundle.cards : bundle.quotes,
                excludeAdmins: _excludeAdmins,
                won: _won,
                onExcludeChanged: (value) =>
                    setState(() => _excludeAdmins = value),
                onRefresh: _load,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.span,
    required this.kind,
    required this.accent,
    required this.report,
    required this.excludeAdmins,
    required this.won,
    required this.onExcludeChanged,
    required this.onRefresh,
  });

  final _UsageSpan span;
  final SalesToolUsageKind kind;
  final Color accent;
  final SalesToolUsageReport report;
  final bool excludeAdmins;
  final NumberFormat won;
  final ValueChanged<bool> onExcludeChanged;
  final Future<void> Function() onRefresh;

  bool get _cards => kind == SalesToolUsageKind.cards;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (report.events.isEmpty) {
      return AppEmpty(
        message: _cards
            ? '${span.menuLabel} 등록된 명함이 없습니다.\n명함을 저장하면 여기에 쌓입니다.'
            : '${span.menuLabel} 작성된 표준단가 견적이 없습니다.\n견적을 저장하면 여기에 쌓입니다.',
        icon: _cards
            ? Icons.contact_page_outlined
            : Icons.request_quote_outlined,
      );
    }

    final ranks = [
      for (final rank in report.ranks)
        if (!excludeAdmins || !rank.isAdmin) rank,
    ];
    final events = [
      for (final event in report.events)
        if (!excludeAdmins || !event.isAdmin) event,
    ];
    final recent = [...ranks]
      ..sort((a, b) {
        final at = (b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        if (at != 0) return at;
        return a.userName.compareTo(b.userName);
      });
    final count = ranks.fold<int>(0, (sum, rank) => sum + rank.count);
    final sent = ranks.fold<int>(0, (sum, rank) => sum + rank.sentCount);
    final amount = ranks.fold<int>(0, (sum, rank) => sum + rank.amountSum);
    final adminCount = report.ranks.where((rank) => rank.isAdmin).length;
    final top = ranks.isEmpty ? null : ranks.first;
    final unit = _cards ? '장' : '건';
    final verb = _cards ? '등록' : '작성';
    final grouped = _groupByDay(events);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: excludeAdmins,
            onChanged: onExcludeChanged,
            title: const Text(
              '관리자 제외',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              adminCount > 0 ? '관리자 $adminCount명' : '관리자 없음',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            _cards
                ? '${span.menuLabel} · 등록한 명함'
                : '${span.menuLabel} · 표준단가에서 저장한 견적',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: verb,
                  value: '$count$unit',
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: '사용자',
                  value: '${ranks.length}명',
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: _cards ? '최근' : '발송',
                  value: _cards
                      ? (recent.isEmpty ? '—' : _shortWhen(recent.first.lastAt))
                      : '$sent건',
                  color: scheme.tertiary,
                ),
              ),
            ],
          ),
          if (!_cards && amount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '견적 합계 ${won.format(amount)}원',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (top != null) ...[
            const SizedBox(height: 16),
            _TopCard(rank: top, unit: unit, verb: verb, accent: accent),
          ],
          const SizedBox(height: 22),
          Text(
            '최근 사용자',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '마지막으로 $verb한 시각',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Text(
              '관리자를 제외하면 표시할 사용자가 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) =>
                    _RecentPerson(rank: recent[index], accent: accent),
              ),
            ),
          const SizedBox(height: 22),
          Text(
            '많이 $verb한 사람',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '$verb 건수 기준 · ${span.menuLabel}',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (ranks.isEmpty)
            Text(
              '관리자를 제외하면 표시할 사용자가 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < ranks.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _RankCard(
                place: i + 1,
                rank: ranks[i],
                maxCount: ranks.first.count,
                unit: unit,
                cards: _cards,
                accent: accent,
              ),
            ],
          const SizedBox(height: 26),
          Text(
            _cards ? '최근 명함' : '최근 견적',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (grouped.isEmpty)
            Text(
              '이 조건에 맞는 기록이 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            for (final day in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  day.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final event in day.value) ...[
                _EventTile(
                  event: event,
                  cards: _cards,
                  accent: accent,
                  won: won,
                ),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.rank,
    required this.unit,
    required this.verb,
    required this.accent,
  });

  final SalesToolUserRank rank;
  final String unit;
  final String verb;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '가장 많이 $verb',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  rank.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (rank.detail.isNotEmpty)
                  Text(
                    rank.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${rank.count}$unit',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPerson extends StatelessWidget {
  const _RecentPerson({required this.rank, required this.accent});

  final SalesToolUserRank rank;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 108,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: accent.withValues(alpha: 0.16),
            child: Text(
              _initial(rank.userName),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const Spacer(),
          Text(
            rank.userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          Text(
            _whenLabel(rank.lastAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.place,
    required this.rank,
    required this.maxCount,
    required this.unit,
    required this.cards,
    required this.accent,
  });

  final int place;
  final SalesToolUserRank rank;
  final int maxCount;
  final String unit;
  final bool cards;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = maxCount <= 0 ? 0.0 : (rank.count / maxCount).clamp(0.0, 1.0);
    final meta = [
      if (rank.detail.isNotEmpty) rank.detail,
      if (rank.isAdmin) '관리자',
      if (rank.lastAt != null) '최근 ${_whenLabel(rank.lastAt)}',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: place <= 3
                      ? accent.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    '$place',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: place <= 3 ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rank.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${rank.count}$unit',
                  style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bar,
                minHeight: 5,
                color: accent,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            if (!cards) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _MiniTag(label: '작성 ${rank.count}'),
                  _MiniTag(label: '발송 ${rank.sentCount}'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.cards,
    required this.accent,
    required this.won,
  });

  final SalesToolEvent event;
  final bool cards;
  final Color accent;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm').format(event.at.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 46,
              child: Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: accent,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (event.subtitle.isNotEmpty)
                    Text(
                      event.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    event.actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!cards && event.sent)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _MiniTag(label: '발송', color: accent),
              ),
            if (!cards && event.amount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  won.format(event.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}

Map<String, List<SalesToolEvent>> _groupByDay(List<SalesToolEvent> events) {
  final map = <String, List<SalesToolEvent>>{};
  for (final event in events) {
    map.putIfAbsent(_dayLabel(event.at), () => []).add(event);
  }
  return map;
}

String _dayLabel(DateTime at) {
  final local = at.toLocal();
  final ymd = DateFormat('yyyy-MM-dd').format(local);
  final today = todayYmdSeoul();
  if (ymd == today) return '오늘';
  if (ymd == addDaysToYmd(today, -1)) return '어제';
  return DateFormat('M월 d일').format(local);
}

String _whenLabel(DateTime? at) {
  if (at == null) return '';
  final local = at.toLocal();
  final ymd = DateFormat('yyyy-MM-dd').format(local);
  final today = todayYmdSeoul();
  final hm = DateFormat('HH:mm').format(local);
  if (ymd == today) return '오늘 $hm';
  if (ymd == addDaysToYmd(today, -1)) return '어제 $hm';
  return DateFormat('M/d HH:mm').format(local);
}

String _shortWhen(DateTime? at) {
  final label = _whenLabel(at);
  if (label.startsWith('오늘 ')) return label.substring(3);
  return label.isEmpty ? '—' : label;
}

String _initial(String name) {
  final text = name.trim();
  if (text.isEmpty) return '?';
  return String.fromCharCode(text.runes.first);
}
