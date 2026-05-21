import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_list_screen.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 홈 [미통화] 구역 — 담당자별 미통화·접수 비율.
class HomeIncompleteBreakdown extends ConsumerStatefulWidget {
  const HomeIncompleteBreakdown({super.key, this.fitSingleScreen = false});

  /// 홈 탭 단일 화면: 세로 스크롤 없이 보이는 담당자 수만 표시.
  final bool fitSingleScreen;

  @override
  ConsumerState<HomeIncompleteBreakdown> createState() =>
      _HomeIncompleteBreakdownState();
}

enum _SummaryFilter { today, week, month, total }

class _HomeIncompleteBreakdownState extends ConsumerState<HomeIncompleteBreakdown> {
  _SummaryFilter _currentFilter = _SummaryFilter.today;

  @override
  Widget build(BuildContext context) {
    final asyncCalls = ref.watch(rankingCallsProvider);
    final masterAsync = ref.watch(masterDataProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) {
        Widget buildWithMaster(MasterDataBundle? master) {
            final todayStr = todayYmdSeoul();
            final now = DateTime.now();
            final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
            final startOfMonth = DateTime(now.year, now.month, 1);

            // 1. Filter calls
            final filteredCalls = calls.where((c) {
              if (c.callDate == null || c.callDate!.length < 10) return _currentFilter == _SummaryFilter.total;
              final callDt = DateTime.tryParse(c.callDate!.substring(0, 10));
              if (callDt == null) return _currentFilter == _SummaryFilter.total;
              switch (_currentFilter) {
                case _SummaryFilter.today: return c.callDate!.startsWith(todayStr);
                case _SummaryFilter.week: return callDt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && callDt.isBefore(now.add(const Duration(days: 1)));
                case _SummaryFilter.month: return callDt.isAfter(startOfMonth.subtract(const Duration(seconds: 1)));
                case _SummaryFilter.total: return true;
              }
            }).toList();

            if (filteredCalls.isEmpty && _currentFilter != _SummaryFilter.total) {
              if (widget.fitSingleScreen) {
                return SizedBox.expand(
                  child: _buildSingleScreenContent(
                    scheme: scheme,
                    sorted: const [],
                    incompleteCounts: const {},
                    totalCounts: const {},
                    totalIncomplete: 0,
                  ),
                );
              }
              return _buildEmptyContent(scheme);
            }

            final total = filteredCalls.length;

            // 2. Count per assignee (Initialize with ALL managers from master data)
            final Map<String, int> incompleteCounts = {};
            final Map<String, int> totalCounts = {};
            
            // Extract managers from regions.
            // 홈 요약은 원본 지역 마스터 담당자 기준 목록을 사용한다.
            if (master != null) {
              for (final r in master.regions) {
                final manager =
                    r.extra['original_manager'] ?? r.extra['manager'] ?? '';
                if (manager.isNotEmpty) {
                  incompleteCounts[manager] = 0;
                  totalCounts[manager] = 0;
                }
              }
            }
            
            // Add counts from filtered calls
            for (var c in filteredCalls) {
              final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
              totalCounts[a] = (totalCounts[a] ?? 0) + 1;
              if (c.isMissed) {
                incompleteCounts[a] = (incompleteCounts[a] ?? 0) + 1;
              } else {
                // Ensure the manager is in our maps even if not in master regions
                incompleteCounts[a] = incompleteCounts[a] ?? 0;
              }
            }

            final sorted = totalCounts.keys.toList()
              ..sort((a, b) {
                // 1. 미통화 많은 순
                final cmp = (incompleteCounts[b] ?? 0).compareTo(incompleteCounts[a] ?? 0);
                if (cmp != 0) return cmp;
                // 2. 전체 건수 많은 순
                return (totalCounts[b] ?? 0).compareTo(totalCounts[a] ?? 0);
              });

            final totalIncomplete =
                incompleteCounts.values.fold<int>(0, (s, v) => s + v);

            if (widget.fitSingleScreen) {
              return SizedBox.expand(
                child: _buildSingleScreenContent(
                  scheme: scheme,
                  sorted: sorted,
                  incompleteCounts: incompleteCounts,
                  totalCounts: totalCounts,
                  totalIncomplete: totalIncomplete,
                ),
              );
            }

            return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.tertiaryContainer.withValues(alpha: 0.5),
                    scheme.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.tertiary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.pending_actions_rounded,
                        size: 22, color: scheme.tertiary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '담당자별 미통화',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '원본 담당자 기준 · ${_filterLabel(_currentFilter)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: totalIncomplete > 0
                          ? scheme.errorContainer.withValues(alpha: 0.7)
                          : scheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalIncomplete건',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: totalIncomplete > 0
                            ? scheme.error
                            : scheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: _SummaryFilter.values.map((filter) {
                    final isSelected = _currentFilter == filter;
                    Color filterColor;
                    String label;
                    
                    switch (filter) {
                      case _SummaryFilter.today: filterColor = scheme.primary; label = '금일'; break;
                      case _SummaryFilter.week: filterColor = scheme.tertiary; label = '금주'; break;
                      case _SummaryFilter.month: filterColor = scheme.secondary; label = '금월'; break;
                      case _SummaryFilter.total: filterColor = scheme.onSurfaceVariant; label = '전체'; break;
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _currentFilter = filter);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.surfaceContainerLowest
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? filterColor : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            ...sorted.asMap().entries.map((entry) {
              final idx = entry.key;
              final name = entry.value;
              final incomplete = incompleteCounts[name] ?? 0;
              final totalPerManager = totalCounts[name] ?? 0;
              final percent = totalPerManager > 0 ? (totalPerManager - incomplete) / totalPerManager : 1.0;
              
              final rank = idx + 1;
              Color rankColor = scheme.primary;
              if (rank == 1) rankColor = const Color(0xFFD4AF37); // Gold
              else if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
              else if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: rankColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalesCallListScreen(
                            mode: ListQueryMode.incomplete,
                            initialAssignee: name,
                            date: _currentFilter == _SummaryFilter.today ? todayYmdSeoul() : null,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: rank <= 3 ? 0.9 : 0.35),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: rank <= 3 
                                    ? Icon(Icons.workspace_premium_rounded, size: 18, color: rankColor)
                                    : Text('$rank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant.withValues(alpha: 0.6))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$incomplete 건',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: incomplete > 0
                                          ? scheme.error
                                          : scheme.secondary,
                                    ),
                                  ),
                                  Text(
                                    '미통화',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent == 1.0 ? Colors.teal : (percent < 0.5 ? scheme.error : scheme.primary),
                              ),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(percent * 100).toInt()}% 완료',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              ),
                              Text(
                                '총 $totalPerManager 건',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ],
                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
        }

        return masterAsync.when(
          data: (m) => buildWithMaster(m),
          loading: () => buildWithMaster(null),
          error: (_, __) => buildWithMaster(null),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => _ErrorCard(
        message: koreanErrorMessage(e),
        onRetry: () => ref.refresh(rankingCallsProvider),
      ),
    );
  }

  String _filterLabel(_SummaryFilter f) => switch (f) {
        _SummaryFilter.today => '금일',
        _SummaryFilter.week => '금주',
        _SummaryFilter.month => '금월',
        _SummaryFilter.total => '전체',
      };

  Widget _buildSingleScreenContent({
    required ColorScheme scheme,
    required List<String> sorted,
    required Map<String, int> incompleteCounts,
    required Map<String, int> totalCounts,
    required int totalIncomplete,
  }) {
    final totalCalls = totalCounts.values.fold<int>(0, (s, v) => s + v);
    final cleared = (totalCalls - totalIncomplete).clamp(0, totalCalls);
    final completePct =
        totalCalls > 0 ? ((cleared / totalCalls) * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIncompleteSummaryCard(
          scheme: scheme,
          totalIncomplete: totalIncomplete,
          totalCalls: totalCalls,
          completePct: completePct,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, listConstraints) {
              if (sorted.isEmpty) {
                return Center(
                  child: Text(
                    '미통화 담당자가 없습니다',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              const cols = 2;
              const tileH = 36.0;
              const gap = 4.0;
              const outerPad = 26.0; // 하단·카드 패딩
              const moreBlock = 34.0;

              final maxColumnH = listConstraints.maxHeight - outerPad;
              final reserveMore =
                  sorted.length > cols * 2 ? moreBlock : 0.0;
              final gridUsable = (maxColumnH - reserveMore).clamp(tileH, maxColumnH);
              final maxRows =
                  ((gridUsable + gap) / (tileH + gap)).floor().clamp(1, 16);
              final maxVisible = (maxRows * cols).clamp(1, sorted.length);
              final visible = sorted.take(maxVisible).toList();
              final hidden = sorted.length - visible.length;
              final showMore = hidden > 0;
              final gridH =
                  maxRows * tileH + (maxRows - 1) * gap;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: gridH,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: gap,
                            mainAxisSpacing: gap,
                            mainAxisExtent: tileH,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final name = visible[i];
                            return _buildIncompleteManagerTile(
                              scheme: scheme,
                              name: name,
                              rank: i + 1,
                              incomplete: incompleteCounts[name] ?? 0,
                              total: totalCounts[name] ?? 0,
                              compact: true,
                            );
                          },
                        ),
                      ),
                      if (showMore) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 28,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SalesCallListScreen(
                                    mode: ListQueryMode.incomplete,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.groups_rounded, size: 14),
                            label: Text('+$hidden명 더보기'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIncompleteSummaryCard({
    required ColorScheme scheme,
    required int totalIncomplete,
    required int totalCalls,
    required int completePct,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: totalIncomplete > 0
                      ? scheme.errorContainer.withValues(alpha: 0.65)
                      : scheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$totalIncomplete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: totalIncomplete > 0
                        ? scheme.error
                        : scheme.secondary,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '미통화 ${_filterLabel(_currentFilter)} · 접수 $totalCalls건 · 완료 $completePct%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildIncompletePeriodFilter(scheme),
        ],
      ),
    );
  }

  Widget _buildIncompletePeriodFilter(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _SummaryFilter.values.map((filter) {
          final isSelected = _currentFilter == filter;
          final color = switch (filter) {
            _SummaryFilter.today => scheme.primary,
            _SummaryFilter.week => scheme.tertiary,
            _SummaryFilter.month => scheme.secondary,
            _SummaryFilter.total => scheme.onSurfaceVariant,
          };
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentFilter = filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _filterLabel(filter),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? color
                        : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _incompleteRankAccent(int rank, ColorScheme scheme) {
    return switch (rank) {
      1 => const Color(0xFFE6A817),
      2 => const Color(0xFF9E9E9E),
      3 => const Color(0xFFB87333),
      _ => scheme.outlineVariant,
    };
  }

  Widget _buildIncompleteManagerTile({
    required ColorScheme scheme,
    required String name,
    required int rank,
    required int incomplete,
    required int total,
    bool compact = false,
  }) {
    final percent = total > 0 ? (total - incomplete) / total : 1.0;
    final accent = _incompleteRankAccent(rank, scheme);
    final initial = name.isNotEmpty ? name[0] : '?';
    final hasIssue = incomplete > 0;
    final progressColor = percent >= 1.0
        ? Colors.teal
        : (percent < 0.5 ? scheme.error : scheme.primary);

    final avatarR = compact ? 9.0 : 10.0;
    final fontSize = compact ? 10.0 : 11.0;

    return SizedBox(
      height: 36,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: hasIssue
                ? scheme.error.withValues(alpha: 0.16)
                : scheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openIncompleteListForAssignee(name),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 5,
                right: 5,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(9),
                  ),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 2,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(compact ? 4 : 6, 4, compact ? 4 : 6, 5),
                child: Row(
                  children: [
                    if (!compact)
                      Container(
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: rank <= 3 ? 1 : 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    if (!compact) const SizedBox(width: 5),
                    CircleAvatar(
                      radius: avatarR,
                      backgroundColor: accent.withValues(alpha: 0.14),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 5),
                    Expanded(
                      child: Text(
                        compact
                            ? '$name\n접수$total·${(percent * 100).round()}%'
                            : '$name · 접수$total · ${(percent * 100).round()}%',
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 4 : 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: hasIssue
                            ? scheme.errorContainer.withValues(alpha: 0.8)
                            : scheme.secondaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        hasIssue ? '$incomplete' : '완료',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: hasIssue ? scheme.error : scheme.secondary,
                          height: 1,
                        ),
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

  void _openIncompleteListForAssignee(String name) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incomplete,
          initialAssignee: name,
          date: _currentFilter == _SummaryFilter.today ? todayYmdSeoul() : null,
        ),
      ),
    );
  }

  Widget _buildEmptyContent(ColorScheme scheme) {
    return Column(
      children: [
        // ─── 필터 버튼 (데이터 없을 때도 동일하게 유지) ───
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: _SummaryFilter.values.map((filter) {
                final isSelected = _currentFilter == filter;
                Color filterColor;
                String label;

                switch (filter) {
                  case _SummaryFilter.today:
                    filterColor = scheme.primary;
                    label = '금일';
                    break;
                  case _SummaryFilter.week:
                    filterColor = scheme.tertiary;
                    label = '금주';
                    break;
                  case _SummaryFilter.month:
                    filterColor = scheme.secondary;
                    label = '금월';
                    break;
                  case _SummaryFilter.total:
                    filterColor = scheme.onSurfaceVariant;
                    label = '전체';
                    break;
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? filterColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 52, color: scheme.outlineVariant),
                const SizedBox(height: 16),
                Text(
                  '선택한 기간에 미통화 건이 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatVertical extends StatelessWidget {
  const _StatVertical({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) onTap!();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, color: scheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: scheme.onErrorContainer, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 홈 [달력] 구역 — 팔로우·예정일 달력.
class HomeFollowCalendarPanel extends ConsumerStatefulWidget {
  const HomeFollowCalendarPanel({
    super.key,
    this.scrollController,
    this.initialCalendarFormat = CalendarFormat.week,
    this.fitSingleScreen = false,
  });

  final ScrollController? scrollController;
  final CalendarFormat initialCalendarFormat;
  final bool fitSingleScreen;

  @override
  ConsumerState<HomeFollowCalendarPanel> createState() =>
      _HomeFollowCalendarPanelState();
}

class _HomeFollowCalendarPanelState extends ConsumerState<HomeFollowCalendarPanel> {
  DateTime _focusedDay = DateTime.now();
  String _selectedAssignee = '전체';
  late CalendarFormat _calendarFormat;
  /// 사용자가 담당자 칩을 직접 탭한 뒤에는 '전체'를 로그인 담당자로 되돌리지 않음.
  bool _userPickedAssigneeFilter = false;

  @override
  void initState() {
    super.initState();
    _calendarFormat = widget.initialCalendarFormat == CalendarFormat.month
        ? CalendarFormat.month
        : CalendarFormat.week;
  }

  @override
  void didUpdateWidget(HomeFollowCalendarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCalendarFormat != widget.initialCalendarFormat) {
      setState(() {
        _calendarFormat = widget.initialCalendarFormat == CalendarFormat.month
            ? CalendarFormat.month
            : CalendarFormat.week;
      });
    }
  }

  String _weekdayKo(int weekday) {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  void _jumpToThisMonth() {
    final now = DateTime.now();
    setState(() {
      _calendarFormat = CalendarFormat.month;
      _focusedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _jumpToThisWeek() {
    final now = DateTime.now();
    setState(() {
      _calendarFormat = CalendarFormat.week;
      _focusedDay = DateTime(now.year, now.month, now.day);
    });
  }

  void _shiftFocusedWeek(int dir) {
    final mon = seoulWeekRangeContaining(_focusedDayYmd()).$1;
    final nextMon = addDaysToYmd(mon, 7 * dir);
    final parts = nextMon.split('-');
    if (parts.length != 3) return;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return;
    setState(() => _focusedDay = DateTime(y, m, d));
  }

  void _openDayFollowList(String dateKey) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SalesCallListScreen(
          mode: ListQueryMode.incompleteByDate,
          date: dateKey,
          initialAssignee: _selectedAssignee,
        ),
      ),
    );
  }

  void _selectAssigneeFilter(String assignee) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAssignee = assignee;
      _userPickedAssigneeFilter = true;
    });
  }

  Widget _buildFitSingleScreenLayout({
    required ColorScheme scheme,
    required List<String> sortedAssignees,
    required Map<String, int> counts,
    required Color Function(String) colorForAssignee,
    required Map<String, int> dateMarkers,
    Map<String, Map<String, int>> weekAssigneeCounts = const {},
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 24,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedAssignees.length,
              itemBuilder: (context, idx) {
                final assignee = sortedAssignees[idx];
                final count = counts[assignee] ?? 0;
                final isSelected = _selectedAssignee == assignee;
                final color = colorForAssignee(assignee);
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => _selectAssigneeFilter(assignee),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 88),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.16)
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color.withValues(alpha: 0.45)
                              : scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              assignee,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 3),
          _buildFitCalendarToolbarRow(scheme),
          const SizedBox(height: 3),
          Expanded(
            child: _calendarFormat == CalendarFormat.week
                ? _buildVerticalWeekBoard(
                    scheme: scheme,
                    weekAssigneeCounts: weekAssigneeCounts,
                    colorForAssignee: colorForAssignee,
                  )
                : _buildCompactCalendar(
                    scheme: scheme,
                    dateMarkers: dateMarkers,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWeekNav(ColorScheme scheme) {
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftFocusedWeek(-1),
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Text(
              formatWeekRangeFlowLabel(w.$1, w.$2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shiftFocusedWeek(1),
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalWeekBoard({
    required ColorScheme scheme,
    required Map<String, Map<String, int>> weekAssigneeCounts,
    required Color Function(String) colorForAssignee,
  }) {
    final weekKeys = _weekYmdKeys();
    final today = todayYmdSeoul();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < weekKeys.length; i++)
                  Expanded(
                    child: _buildVerticalWeekDayRow(
                      scheme: scheme,
                      dateKey: weekKeys[i],
                      dayMap: weekAssigneeCounts[weekKeys[i]] ?? const {},
                      colorForAssignee: colorForAssignee,
                      isToday: weekKeys[i] == today,
                      showBottomBorder: i < weekKeys.length - 1,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalWeekDayRow({
    required ColorScheme scheme,
    required String dateKey,
    required Map<String, int> dayMap,
    required Color Function(String) colorForAssignee,
    required bool isToday,
    bool showBottomBorder = false,
  }) {
    final parts = dateKey.split('-');
    final month = parts.length == 3 ? int.tryParse(parts[1]) ?? 0 : 0;
    final dayNum = parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
    final weekday = parts.length == 3
        ? DateTime(
            int.tryParse(parts[0]) ?? 0,
            month,
            dayNum,
          ).weekday
        : 1;
    final sorted = dayMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    Color weekdayColor = scheme.onSurfaceVariant;
    if (weekday == DateTime.saturday) weekdayColor = Colors.blueAccent;
    if (weekday == DateTime.sunday) weekdayColor = Colors.redAccent;

    final filteredOnly = _selectedAssignee != '전체';

    return Material(
      color: isToday
          ? scheme.primaryContainer.withValues(alpha: 0.22)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _openDayFollowList(dateKey);
        },
        child: Container(
          decoration: showBottomBorder
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.22),
                    ),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76,
                padding: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Text(
                  '$month/$dayNum(${_weekdayKo(weekday)})',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isToday ? scheme.primary : weekdayColor,
                    height: 1.1,
                  ),
                ),
              ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '$total건',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: scheme.error,
                      height: 1.05,
                    ),
                  ),
                ),
              Expanded(
                child: total == 0
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '팔로우 없음',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                        ),
                      )
                    : filteredOnly
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${_selectedAssignee} ${dayMap[_selectedAssignee] ?? 0}건',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: colorForAssignee(_selectedAssignee),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Row(
                              children: sorted.map((e) {
                                final c = colorForAssignee(e.key);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: c.withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Text(
                                      '${e.key} ${e.value}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: c,
                                        height: 1.05,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 홈 단일 화면: 주 이동 + 주간/월간 토글을 한 줄로.
  Widget _buildFitCalendarToolbarRow(ColorScheme scheme) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    final shortcutColor = isWeek ? Colors.teal : Colors.indigo;
    final w = seoulWeekRangeContaining(_focusedDayYmd());

    Widget navBtn({required IconData icon, required VoidCallback onTap}) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          minimumSize: const Size(26, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    Widget formatChip({
      required bool selected,
      required String label,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: selected ? activeColor : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (isWeek) ...[
            navBtn(
              icon: Icons.chevron_left_rounded,
              onTap: () => _shiftFocusedWeek(-1),
            ),
            Expanded(
              child: Text(
                formatWeekRangeFlowLabel(w.$1, w.$2),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            navBtn(
              icon: Icons.chevron_right_rounded,
              onTap: () => _shiftFocusedWeek(1),
            ),
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ],
          formatChip(
            selected: isWeek,
            label: '주간',
            activeColor: Colors.teal,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _calendarFormat = CalendarFormat.week);
            },
          ),
          const SizedBox(width: 4),
          formatChip(
            selected: !isWeek,
            label: '월간',
            activeColor: Colors.indigo,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _calendarFormat = CalendarFormat.month);
            },
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: isWeek ? _jumpToThisWeek : _jumpToThisMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: BoxDecoration(
                color: shortcutColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: shortcutColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                isWeek ? '이번주' : '이번달',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: shortcutColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFormatToggleRow(ColorScheme scheme) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    final shortcutColor = isWeek ? Colors.teal : Colors.indigo;

    Widget formatChip({
      required bool selected,
      required String label,
      required IconData icon,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? activeColor.withValues(alpha: 0.35)
                    : scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: selected ? activeColor : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? activeColor : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWeek) ...[
            _buildInlineWeekNav(scheme),
            const SizedBox(height: 2),
          ],
          Row(
            children: [
              formatChip(
                selected: isWeek,
                label: '주간',
                icon: Icons.view_week_rounded,
                activeColor: Colors.teal,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _calendarFormat = CalendarFormat.week);
                },
              ),
              const SizedBox(width: 4),
              formatChip(
                selected: !isWeek,
                label: '월간',
                icon: Icons.calendar_month_rounded,
                activeColor: Colors.indigo,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _calendarFormat = CalendarFormat.month);
                },
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isWeek ? _jumpToThisWeek : _jumpToThisMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: shortcutColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: shortcutColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    isWeek ? '이번주' : '이번달',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: shortcutColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCalendar({
    required ColorScheme scheme,
    required Map<String, int> dateMarkers,
  }) {
    final isWeek = _calendarFormat == CalendarFormat.week;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: TableCalendar(
        key: ValueKey(_calendarFormat),
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: const {
          CalendarFormat.week: '주간',
          CalendarFormat.month: '월간',
        },
        onFormatChanged: (format) {
          if (_calendarFormat == format) return;
          setState(() => _calendarFormat = format);
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        locale: 'ko_KR',
        daysOfWeekHeight: isWeek ? 18 : 22,
        rowHeight: isWeek ? 26 : 32,
        availableGestures: AvailableGestures.none,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: EdgeInsets.symmetric(vertical: isWeek ? 2 : 4),
          titleTextStyle: TextStyle(
            fontSize: isWeek ? 12 : 13,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekendStyle: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
        calendarStyle: const CalendarStyle(
          holidayTextStyle: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            final txt = _weekdayKo(day.weekday);
            Color color = scheme.onSurfaceVariant;
            if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
            if (day.weekday == DateTime.sunday) color = Colors.redAccent;
            return Center(
              child: Text(
                txt,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            Color color = scheme.onSurface;
            if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
            if (day.weekday == DateTime.sunday) color = Colors.redAccent;
            return Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            final dateKey = date.toIso8601String().substring(0, 10);
            final count = dateMarkers[dateKey] ?? 0;
            if (count <= 0) return null;
            return Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 12,
                height: 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() => _focusedDay = focusedDay);
          final dateStr = selectedDay.toIso8601String().substring(0, 10);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SalesCallListScreen(
                mode: ListQueryMode.incompleteByDate,
                date: dateStr,
                initialAssignee: _selectedAssignee,
              ),
            ),
          );
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
        },
      ),
    );
  }

  Color _strongColorForAssignee(String assignee) {
    if (assignee == '전체') return Colors.blueGrey.shade700;
    if (assignee == '미지정') return Colors.grey.shade700;
    final colors = [
      Colors.blue.shade700,
      Colors.red.shade700,
      Colors.green.shade700,
      Colors.orange.shade800,
      Colors.purple.shade700,
      Colors.teal.shade700,
      Colors.indigo.shade700,
    ];
    return colors[assignee.hashCode.abs() % colors.length];
  }

  String _calendarAssignee(SalesCall c, List<TempManagerOverride> overrides) {
    return displayAssigneeForCall(c, overrides, DateTime.now());
  }

  String _focusedDayYmd() =>
      '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}-${_focusedDay.day.toString().padLeft(2, '0')}';

  CalendarFollowRangeKey _calendarRangeKey() {
    if (_calendarFormat == CalendarFormat.month) {
      final m = seoulMonthRangeContaining(_focusedDayYmd());
      return (startYmd: m.$1, endYmd: m.$2);
    }
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    return (startYmd: w.$1, endYmd: w.$2);
  }

  List<String> _weekYmdKeys() {
    final w = seoulWeekRangeContaining(_focusedDayYmd());
    final keys = <String>[w.$1];
    var cur = w.$1;
    for (var i = 0; i < 6; i++) {
      cur = addDaysToYmd(cur, 1);
      keys.add(cur);
    }
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final rangeKey = _calendarRangeKey();
    final asyncCalls = ref.watch(calendarFollowRangeProvider(rangeKey));
    final overridesAsync = ref.watch(tempManagerOverridesProvider);
    final scheme = Theme.of(context).colorScheme;

    return asyncCalls.when(
      data: (calls) => overridesAsync.when(
        data: (overrides) => _buildCalendarBody(calls, overrides, scheme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(koreanErrorMessage(e))),
    );
  }

  Widget _buildCalendarBody(
    List<SalesCall> calls,
    List<TempManagerOverride> overrides,
    ColorScheme scheme,
  ) {
        // API `followRange` + 목록 `incompleteByDate`와 동일 조건(서버에서 이미 미종료·단순문의 제외)
        final followCalls =
            calls.where((c) => c.followCalendarDateKey != null).toList();

        final focusedMonthStr = _focusedDayYmd().substring(0, 7);
        final weekYmdSet = _weekYmdKeys().toSet();

        bool inFocusedPeriod(String? followYmd) {
          if (followYmd == null || followYmd.length < 10) return false;
          final key = followYmd.substring(0, 10);
          if (_calendarFormat == CalendarFormat.month) {
            return key.startsWith(focusedMonthStr);
          }
          return weekYmdSet.contains(key);
        }

        final visibleCallsInPeriod =
            followCalls.where((c) => inFocusedPeriod(c.followCalendarDateKey)).toList();

        final Map<String, int> counts = {'전체': visibleCallsInPeriod.length};
        for (var c in visibleCallsInPeriod) {
          final a = _calendarAssignee(c, overrides);
          counts[a] = (counts[a] ?? 0) + 1;
        }

        final sortedAssignees = counts.keys.toList()
          ..sort((a, b) {
            if (a == '전체') return -1;
            if (b == '전체') return 1;
            final countA = counts[a] ?? 0;
              final countB = counts[b] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            return a.compareTo(b);
          });

        // 담당자별 색상 충돌 방지: 화면 내 팔레트 맵을 고정 생성
        final palette = <Color>[
          Colors.blue.shade700,
          Colors.red.shade700,
          Colors.green.shade700,
          Colors.orange.shade800,
          Colors.purple.shade700,
          Colors.teal.shade700,
          Colors.indigo.shade700,
          Colors.pink.shade700,
          Colors.cyan.shade700,
          Colors.brown.shade700,
        ];
        final assigneeColorMap = <String, Color>{};
        var paletteIdx = 0;
        for (final a in sortedAssignees) {
          if (a == '전체') {
            assigneeColorMap[a] = Colors.blueGrey.shade700;
            continue;
          }
          if (a == '미지정') {
            assigneeColorMap[a] = Colors.grey.shade700;
            continue;
          }
          assigneeColorMap[a] = palette[paletteIdx % palette.length];
          paletteIdx += 1;
        }
        Color colorForAssignee(String name) =>
            assigneeColorMap[name] ?? _strongColorForAssignee(name);

        // 최초 진입 시에만 로그인 담당자로 기본 선택 (이후 '전체' 탭은 유지)
        final user = ref.watch(authControllerProvider);
        final userName = user?.name;
        if (!_userPickedAssigneeFilter &&
            _selectedAssignee == '전체' &&
            userName != null &&
            counts.containsKey(userName)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                _userPickedAssigneeFilter ||
                _selectedAssignee != '전체') {
              return;
            }
            setState(() => _selectedAssignee = userName);
          });
        }

        // 3. Prepare calendar markers (group by date) filtered by selected assignee
        final Map<String, int> dateMarkers = {};
        for (final c in followCalls) {
          final a = _calendarAssignee(c, overrides);
          if (_selectedAssignee != '전체' && a != _selectedAssignee) continue;

          final fk = c.followCalendarDateKey;
          if (fk != null && inFocusedPeriod(fk)) {
            final dateKey = fk.substring(0, 10);
            dateMarkers[dateKey] = (dateMarkers[dateKey] ?? 0) + 1;
          }
        }

        final weekYmdKeys = _weekYmdKeys();
        final Map<String, Map<String, int>> weekAssigneeCounts = {
          for (final ymd in weekYmdKeys) ymd: <String, int>{},
        };
        for (final c in followCalls) {
          final fk = c.followCalendarDateKey;
          if (fk == null || fk.length < 10) continue;
          final dateKey = fk.substring(0, 10);
          final bucket = weekAssigneeCounts[dateKey];
          if (bucket == null) continue;
          final assignee = _calendarAssignee(c, overrides);
          if (_selectedAssignee != '전체' && assignee != _selectedAssignee) continue;
          bucket[assignee] = (bucket[assignee] ?? 0) + 1;
        }

        if (widget.fitSingleScreen) {
          return SizedBox.expand(
            child: _buildFitSingleScreenLayout(
              scheme: scheme,
              sortedAssignees: sortedAssignees,
              counts: counts,
              colorForAssignee: colorForAssignee,
              dateMarkers: dateMarkers,
              weekAssigneeCounts: weekAssigneeCounts,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final key = _calendarRangeKey();
            ref.invalidate(calendarFollowRangeProvider(key));
            await ref.read(calendarFollowRangeProvider(key).future);
          },
          child: ListView(
            controller: widget.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.secondaryContainer.withValues(alpha: 0.5),
                    scheme.surface,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.secondary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded,
                        size: 22, color: scheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '팔로우 달력',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          _calendarFormat == CalendarFormat.week
                              ? '주간 일정 · 담당자별 건수'
                              : '월간 일정 · 담당자별 건수',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ─── 상단 담당자 필터 바 (캘린더용) ───
            SizedBox(
              height: 38,
              width: double.infinity,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: sortedAssignees.length,
                itemBuilder: (context, idx) {
                  final assignee = sortedAssignees[idx];
                  final count = counts[assignee] ?? 0;
                  final isSelected = _selectedAssignee == assignee;

                  return Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: GestureDetector(
                      onTap: () => _selectAssigneeFilter(assignee),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _strongColorForAssignee(assignee).withValues(alpha: 0.18)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: _strongColorForAssignee(assignee).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ] : [],
                          border: Border.all(
                            color: isSelected
                                ? _strongColorForAssignee(assignee).withValues(alpha: 0.45)
                                : scheme.outlineVariant.withValues(alpha: 0.3),
                            width: isSelected ? 1.6 : 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorForAssignee(assignee),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              assignee,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.1,
                                color: colorForAssignee(assignee),
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorForAssignee(assignee)
                                    : colorForAssignee(assignee).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? Colors.white : colorForAssignee(assignee),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // ─── 캘린더 영역 ───
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              ),
                  child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _calendarFormat = CalendarFormat.week),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _calendarFormat == CalendarFormat.week
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _calendarFormat == CalendarFormat.week
                                      ? Colors.teal.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                ),
                                boxShadow: _calendarFormat == CalendarFormat.week
                                    ? [
                                        BoxShadow(
                                          color: Colors.teal.withValues(alpha: 0.16),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.view_week_rounded,
                                    size: 14,
                                    color: _calendarFormat == CalendarFormat.week
                                        ? Colors.teal
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '주간 달력',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _calendarFormat == CalendarFormat.week
                                          ? Colors.teal
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _calendarFormat = CalendarFormat.month),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _calendarFormat == CalendarFormat.month
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _calendarFormat == CalendarFormat.month
                                      ? Colors.indigo.withValues(alpha: 0.35)
                                      : Colors.transparent,
                                ),
                                boxShadow: _calendarFormat == CalendarFormat.month
                                    ? [
                                        BoxShadow(
                                          color: Colors.indigo.withValues(alpha: 0.16),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 14,
                                    color: _calendarFormat == CalendarFormat.month
                                        ? Colors.indigo
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '월간 달력',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _calendarFormat == CalendarFormat.month
                                          ? Colors.indigo
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _calendarFormat == CalendarFormat.month ? _jumpToThisMonth : _jumpToThisWeek,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: (_calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _calendarFormat == CalendarFormat.month ? '이번달' : '이번주',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _calendarFormat == CalendarFormat.month ? Colors.indigo : Colors.teal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final isWeekView = _calendarFormat == CalendarFormat.week;
                return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeekView ? 16 : 24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3), width: 1.5),
              ),
              padding: EdgeInsets.all(isWeekView ? 6 : 12),
                child: TableCalendar(
                  key: ValueKey(_calendarFormat),
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  availableCalendarFormats: const {
                    CalendarFormat.week: '주간',
                    CalendarFormat.month: '월간',
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat == format) return;
                    setState(() => _calendarFormat = format);
                  },
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  locale: 'ko_KR',
                  daysOfWeekHeight: isWeekView ? 20 : 34,
                  rowHeight: isWeekView ? 28 : 46,
                  availableGestures: AvailableGestures.none,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    headerPadding: EdgeInsets.symmetric(vertical: isWeekView ? 2 : 8),
                    titleTextStyle: TextStyle(
                      fontSize: isWeekView ? 13 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekendStyle: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    holidayTextStyle: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    dowBuilder: (context, day) {
                      final txt = _weekdayKo(day.weekday);
                      Color color = scheme.onSurfaceVariant;
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent;
                      return Center(
                        child: Text(
                          txt,
                          style: TextStyle(
                            fontSize: isWeekView ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      Color color = scheme.onSurface;
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent;
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent;
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: isWeekView ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      );
                    },
                    outsideBuilder: (context, day, focusedDay) {
                      Color color = scheme.onSurfaceVariant.withValues(alpha: 0.45);
                      if (day.weekday == DateTime.saturday) color = Colors.blueAccent.withValues(alpha: 0.5);
                      if (day.weekday == DateTime.sunday) color = Colors.redAccent.withValues(alpha: 0.5);
                      return Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
                        ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      final dateKey = date.toIso8601String().substring(0, 10);
                      final count = dateMarkers[dateKey] ?? 0;
                      if (count > 0) {
                        final markerSize = isWeekView ? 14.0 : 18.0;
                        return Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: markerSize,
                            height: markerSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.error,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: TextStyle(
                                color: scheme.onError,
                                fontSize: isWeekView ? 8 : 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                    final dateStr = selectedDay.toIso8601String().substring(0, 10);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SalesCallListScreen(
                          mode: ListQueryMode.incompleteByDate,
                          date: dateStr,
                          initialAssignee: _selectedAssignee,
                        ),
                      ),
                    );
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                ),
              );
              },
            ),
            if (_calendarFormat == CalendarFormat.week) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.view_week_rounded, size: 12, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '주간 상세',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...weekYmdKeys.map((dateKey) {
                      final dayMap = weekAssigneeCounts[dateKey] ?? const <String, int>{};
                      final total = dayMap.values.fold<int>(0, (sum, v) => sum + v);
                      final sorted = dayMap.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final parts = dateKey.split('-');
                      final month = parts.length == 3 ? int.tryParse(parts[1]) ?? 0 : 0;
                      final dayNum = parts.length == 3 ? int.tryParse(parts[2]) ?? 0 : 0;
                      final weekday = parts.length == 3
                          ? DateTime(int.tryParse(parts[0]) ?? 0, month, dayNum).weekday
                          : 1;
                      final isToday = dateKey == todayYmdSeoul();

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SalesCallListScreen(
                                mode: ListQueryMode.incompleteByDate,
                                date: dateKey,
                                initialAssignee: _selectedAssignee,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday ? scheme.primaryContainer.withValues(alpha: 0.25) : scheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isToday ? scheme.primary.withValues(alpha: 0.45) : scheme.outlineVariant.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '$month/$dayNum (${_weekdayKo(weekday)})',
                                  style: TextStyle(
                                    fontSize: 9,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: total == 0
                                    ? Text(
                                        '데이터 없음',
                                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
                                      )
                                    : Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: sorted
                                            .map(
                                              (e) => Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(10),
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute<void>(
                                                        builder: (_) => SalesCallListScreen(
                                                          mode: ListQueryMode.incompleteByDate,
                                                          date: dateKey,
                                                          initialAssignee: e.key,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: colorForAssignee(e.key).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '${e.key} ${e.value}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: colorForAssignee(e.key),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 30,
                                child: Text(
                                  '$total건',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: scheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            ],
          ),
        );
  }
}

