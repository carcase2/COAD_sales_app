import 'package:coad_customer_calls/features/quoter/estimate_writer_screen.dart';
import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// COAD_home 셔터 견적기 + 견적서 작성 허브.
class QuoterHubScreen extends StatelessWidget {
  const QuoterHubScreen({
    super.key,
    this.showAppBar = true,
    this.initialTabIndex = 0,
  });

  /// 메인 탭 등 상위 Scaffold 안이면 false.
  final bool showAppBar;

  /// 0 = 셔터 견적기, 1 = 견적서 작성.
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex.clamp(0, 1),
      child: Column(
        children: [
          Material(
            color: scheme.surfaceContainerLow,
            child: TabBar(
              onTap: (_) => HapticFeedback.selectionClick(),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: scheme.outlineVariant.withValues(alpha: 0.35),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                const Tab(
                  height: 40,
                  text: '셔터 견적기',
                ),
                Tab(
                  height: 40,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '견적서 작성 ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '(테스트중)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                QuoterScreen(showQuickActions: false),
                EstimateWriterScreen(),
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
        title: const Text('셔터 견적'),
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
