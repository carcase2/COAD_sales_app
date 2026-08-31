import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_reception_list_screen.dart';
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/features/gosu_calls/gosu_call_create_screen.dart';
import 'package:coad_customer_calls/features/home/home_navigation.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/theme/app_motion.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 하단 접수 · 유형 전환 탭이 있는 등록 화면.
/// [initialKind]가 없으면 지금 홈에서 보고 있는 부서 탭을 연다.
Future<void> openReceptionCreateHost(
  BuildContext context, {
  ReceptionKind? initialKind,
}) async {
  final created = await Navigator.of(context).push<Object?>(
    AppMotion.fadeSlideRoute<Object?>(
      settings: const RouteSettings(name: kReceptionCreateRouteName),
      builder: (_) => ReceptionCreateHostScreen(initialKind: initialKind),
    ),
  );
  if (!context.mounted || created is! SupportCallLog) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('접수가 저장되었습니다. 1차 상담을 남겨 주세요.')));
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => CustomerSupportReceptionDetailScreen(log: created),
    ),
  );
}

class ReceptionCreateHostScreen extends ConsumerStatefulWidget {
  const ReceptionCreateHostScreen({super.key, this.initialKind});

  final ReceptionKind? initialKind;

  @override
  ConsumerState<ReceptionCreateHostScreen> createState() =>
      _ReceptionCreateHostScreenState();
}

class _ReceptionCreateHostScreenState
    extends ConsumerState<ReceptionCreateHostScreen> {
  late ReceptionKind _kind;
  final ReceptionUnsavedRegistry _unsaved = ReceptionUnsavedRegistry();
  final Set<ReceptionKind> _built = {};

  @override
  void initState() {
    super.initState();
    _kind =
        widget.initialKind ??
        receptionKindForHomeDeptPage(ref.read(homeDeptPageIndexProvider));
    _built.add(_kind);
  }

  int get _tabIndex => switch (_kind) {
    ReceptionKind.sales => 0,
    ReceptionKind.afterSales => 1,
    ReceptionKind.gosu => 2,
  };

  Color _accent(ColorScheme scheme) => switch (_kind) {
    ReceptionKind.sales => scheme.primary,
    ReceptionKind.afterSales => AppTokens.customerSupportAccent(scheme),
    ReceptionKind.gosu => AppTokens.gosuAccent(scheme),
  };

  Future<bool> _confirmLeave() async {
    if (!_unsaved.hasAnyUnsaved) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('작성 취소'),
        content: const Text('작성 중인 접수 내용이 있습니다.\n저장하지 않고 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 작성'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _selectKind(ReceptionKind kind) {
    if (_kind == kind) return;
    HapticFeedback.selectionClick();
    setState(() {
      _kind = kind;
      _built.add(kind);
    });
  }

  Widget _pane({required ReceptionKind kind, required Widget child}) {
    if (!_built.contains(kind)) return const SizedBox.shrink();
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(scheme);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmLeave()) return;
        if (!mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('새 접수'),
          backgroundColor: accent,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_rounded),
              tooltip: '홈으로 이동',
              onPressed: () async {
                if (await _confirmLeave() && context.mounted) {
                  navigateToHomeAndRefresh(context, ref);
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _ReceptionKindTabs(
                index: _tabIndex,
                onSelected: (i) => _selectKind(switch (i) {
                  1 => ReceptionKind.afterSales,
                  2 => ReceptionKind.gosu,
                  _ => ReceptionKind.sales,
                }),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _pane(
                    kind: ReceptionKind.sales,
                    child: SalesCallCreateScreen(
                      embedded: true,
                      unsavedRegistry: _unsaved,
                    ),
                  ),
                  _pane(
                    kind: ReceptionKind.afterSales,
                    child: CustomerSupportIntakeScreen(
                      embedded: true,
                      unsavedRegistry: _unsaved,
                    ),
                  ),
                  _pane(
                    kind: ReceptionKind.gosu,
                    child: GosuCallCreateScreen(
                      embedded: true,
                      unsavedRegistry: _unsaved,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceptionKindTabs extends StatelessWidget {
  const _ReceptionKindTabs({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  static const _labels = ['영업', 'A/S', '자동문의고수'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color accentFor(int i) => switch (i) {
      1 => AppTokens.customerSupportAccent(scheme),
      2 => AppTokens.gosuAccent(scheme),
      _ => scheme.primary,
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: index == i ? accentFor(i) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: index == i
                          ? Colors.white
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
