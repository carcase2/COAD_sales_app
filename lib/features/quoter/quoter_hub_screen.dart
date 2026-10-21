import 'package:coad_customer_calls/features/quoter/size_first_quote_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_writer_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 견적 탭: 사이즈로 모델 비교 · 견적서.
class QuoterHubScreen extends ConsumerStatefulWidget {
  const QuoterHubScreen({
    super.key,
    this.showAppBar = true,
    this.initialTabIndex = 0,
  });

  /// 메인 탭 등 상위 Scaffold 안이면 false.
  final bool showAppBar;

  /// 0 = 사이즈 비교, 1 = 견적서.
  final int initialTabIndex;

  @override
  ConsumerState<QuoterHubScreen> createState() => _QuoterHubScreenState();
}

class _QuoterHubScreenState extends ConsumerState<QuoterHubScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
      vsync: this,
    );
    _tabController!.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackCurrentTab();
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController == null || _tabController!.indexIsChanging) {
      return;
    }
    _trackCurrentTab();
  }

  void _trackCurrentTab() {
    final user = ref.read(authControllerProvider);
    if (user == null) return;
    final index = _tabController?.index ?? 0;
    final key = switch (index) {
      0 => 'size_first_quote',
      1 => 'quoter_list',
      _ => 'quoter',
    };
    UsageService.recordTab(userId: user.id, userName: user.name, tabKey: key);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Column(
      children: [
        Material(
          color: scheme.surfaceContainerLow,
          child: TabBar(
            controller: _tabController,
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
              Tab(height: 40, child: _HubTabLabel('사이즈')),
              Tab(height: 40, child: _HubTabLabel('견적서')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              SizeFirstQuoteScreen(),
              SizeQuoteWriterScreen(embedded: true),
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

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
