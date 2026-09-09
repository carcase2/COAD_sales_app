import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_writer_screen.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 견적 탭: 셔터 견적기 · 표준단가 · 견적서(검색·재사용).
class QuoterHubScreen extends StatelessWidget {
  const QuoterHubScreen({
    super.key,
    this.showAppBar = true,
    this.initialTabIndex = 0,
  });

  /// 메인 탭 등 상위 Scaffold 안이면 false.
  final bool showAppBar;

  /// 0 = 셔터 견적기, 1 = 표준단가, 2 = 견적서.
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex.clamp(0, 2),
      child: Column(
        children: [
          Material(
            color: scheme.surfaceContainerLow,
            child: TabBar(
              onTap: (_) => HapticFeedback.selectionClick(),
              indicatorSize: TabBarIndicatorSize.tab,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              dividerColor: scheme.outlineVariant.withValues(alpha: 0.35),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(height: 40, child: _HubTabLabel('셔터 견적기')),
                Tab(height: 40, child: _HubTabLabel('표준단가')),
                Tab(height: 40, child: _HubTabLabel('견적서')),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                QuoterScreen(showQuickActions: false),
                StandardUnitPriceScreen(showAppBar: false),
                SizeQuoteWriterScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );

    if (!showAppBar) return body;

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      // 규격 입력 시 숫자 키보드가 칸을 가리지 않도록 body 축소
      resizeToAvoidBottomInset: true,
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

/// 좁은 화면에서도 탭 글자가 잘리지 않게 축소.
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
