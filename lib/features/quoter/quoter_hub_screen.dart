import 'dart:async';

import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 견적 탭: 견적서 목록이 첫 화면. 위의 「빠른 단가」로 셔터 견적기·표준단가를 연다.
/// 새 견적서는 목록의 「새 견적서」에서 제품(표준단가·셔터·직접 입력)을 골라 시작한다.
class QuoterHubScreen extends ConsumerStatefulWidget {
  const QuoterHubScreen({super.key, this.showAppBar = true});

  /// 메인 탭 등 상위 Scaffold 안이면 false.
  final bool showAppBar;

  @override
  ConsumerState<QuoterHubScreen> createState() => _QuoterHubScreenState();
}

class _QuoterHubScreenState extends ConsumerState<QuoterHubScreen> {
  /// 빠른 단가에서 견적서를 저장하고 돌아오면 목록을 다시 읽게 바꾼다.
  int _listGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _track('quoter_list');
    });
  }

  void _track(String key) {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    UsageService.recordTab(userId: user.id, userName: user.name, tabKey: key);
  }

  Future<void> _openShutter() async {
    HapticFeedback.selectionClick();
    _track('shutter_quoter');
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          // 규격 입력 시 숫자 키보드가 칸을 가리지 않도록 body 축소
          resizeToAvoidBottomInset: true,
          appBar: AppBar(title: const Text('셔터 견적기'), toolbarHeight: 48),
          body: const QuoterScreen(showQuickActions: false),
        ),
      ),
    );
    if (mounted) setState(() => _listGeneration++);
  }

  Future<void> _openStandard() async {
    HapticFeedback.selectionClick();
    _track('standard_unit_price');
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const StandardUnitPriceScreen()),
    );
    if (mounted) setState(() => _listGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Column(
      children: [
        Material(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Text(
                  '빠른 단가',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickPriceButton(
                    icon: Icons.calculate_rounded,
                    label: '셔터 견적기',
                    onTap: () => unawaited(_openShutter()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickPriceButton(
                    icon: Icons.grid_on_rounded,
                    label: '표준단가',
                    onTap: () => unawaited(_openStandard()),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SizeQuoteWriterScreen(
            key: ValueKey(_listGeneration),
            embedded: true,
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: const Text('견적'),
        toolbarHeight: 48,
        automaticallyImplyLeading: canPop,
        actions: [
          if (canPop)
            IconButton(
              tooltip: '홈으로',
              icon: const Icon(Icons.home_rounded),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _QuickPriceButton extends StatelessWidget {
  const _QuickPriceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(icon, size: 18),
      label: _HubTabLabel(label),
    );
  }
}

/// 좁은 화면에서도 버튼 글자가 잘리지 않게 축소.
class _HubTabLabel extends StatelessWidget {
  const _HubTabLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, textAlign: TextAlign.center),
    );
  }
}
