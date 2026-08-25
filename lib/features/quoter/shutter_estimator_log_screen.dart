import 'dart:async';

import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/core/widgets/app_async_states.dart';
import 'package:coad_customer_calls/data/shutter_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// COAD_home 관리자 「셔터 견적기 사용 이력」 화면.
class ShutterEstimatorLogScreen extends ConsumerStatefulWidget {
  const ShutterEstimatorLogScreen({super.key});

  @override
  ConsumerState<ShutterEstimatorLogScreen> createState() =>
      _ShutterEstimatorLogScreenState();
}

class _ShutterEstimatorLogScreenState
    extends ConsumerState<ShutterEstimatorLogScreen> {
  /// `0` = 전체 기간.
  int _periodDays = 30;
  AsyncValue<ShutterEstimatorLogBundle> _data = const AsyncLoading();

  final _won = NumberFormat('#,###');
  final _dt = DateFormat('yyyy.MM.dd HH:mm');

  static const _periodAll = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final user = ref.read(authControllerProvider);
    if (!isAppAdmin(user)) {
      setState(
        () => _data = AsyncError(
          StateError('관리자만 조회할 수 있습니다.'),
          StackTrace.current,
        ),
      );
      return;
    }

    setState(() => _data = const AsyncLoading());
    try {
      final since = _periodDays == _periodAll
          ? null
          : DateTime.now().subtract(Duration(days: _periodDays));
      final bundle = await ref
          .read(shutterRepositoryProvider)
          .fetchEstimatorLogs(since: since, limit: 200);
      if (!mounted) return;
      setState(() => _data = AsyncData(bundle));
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _data = AsyncError(e, st));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider);

    if (!isAdminGroup(user)) {
      return Scaffold(
        appBar: AppBar(title: const Text('견적기 사용 이력')),
        body: const AppEmpty(
          message: '관리자 그룹만 조회할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('견적기 사용 이력'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () {
              HapticFeedback.selectionClick();
              unawaited(_load());
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기간',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  // 선택 체크 아이콘이 좁은 세그먼트에서 라벨 줄바꿈을 유발함
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _periodAll,
                      label: Text('전체', maxLines: 1),
                    ),
                    ButtonSegment(
                      value: 7,
                      label: Text('7일', maxLines: 1),
                    ),
                    ButtonSegment(
                      value: 30,
                      label: Text('30일', maxLines: 1),
                    ),
                    ButtonSegment(
                      value: 90,
                      label: Text('90일', maxLines: 1),
                    ),
                    ButtonSegment(
                      value: 365,
                      label: Text('1년', maxLines: 1),
                    ),
                  ],
                  selected: {_periodDays},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _periodDays = s.first);
                    unawaited(_load());
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 4),
                    ),
                    textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _data.when(
              loading: () => const AppLoading(message: '이력을 불러오는 중…'),
              error: (e, _) => AppErrorState(
                message: koreanErrorMessage(e),
                onRetry: () => unawaited(_load()),
              ),
              data: (bundle) => RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    _SummaryRow(
                      totalCount: bundle.totalCount,
                      userCount: bundle.byUser.length,
                      totalPrice: bundle.totalPriceSum,
                      won: _won,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '사용자별 사용 빈도',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (bundle.byUser.isEmpty)
                      const AppEmpty(
                        message: '해당 기간 데이터가 없습니다.',
                        icon: Icons.person_search_rounded,
                      )
                    else
                      ...bundle.byUser.map(
                        (u) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              child: Text(
                                u.userName.isNotEmpty
                                    ? u.userName.characters.first
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              u.userName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '견적액 합계 ${_won.format(u.totalPriceSum)}원',
                            ),
                            trailing: Text(
                              '${_won.format(u.count)}회',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '상세 이력 (최근 ${bundle.history.length}건)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (bundle.history.isEmpty)
                      const AppEmpty(
                        message: '이력이 없습니다.',
                        icon: Icons.inbox_outlined,
                      )
                    else
                      ...bundle.history.map(
                        (row) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        row.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _dt.format(row.createdAt.toLocal()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${row.modelType} · ${row.widthMm}×${row.heightMm}mm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_won.format(row.totalPrice)}원',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.primary,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalCount,
    required this.userCount,
    required this.totalPrice,
    required this.won,
  });

  final int totalCount;
  final int userCount;
  final int totalPrice;
  final NumberFormat won;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: '총 사용',
            value: '${won.format(totalCount)}회',
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '사용자',
            value: '$userCount명',
            color: scheme.tertiary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: '견적액 합',
            value: '${won.format(totalPrice)}원',
            color: scheme.secondary,
            compact: true,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 13 : 16,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
