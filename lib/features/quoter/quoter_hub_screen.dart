import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/usage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 견적 탭: 분류(셔터·스피드도어·차고문) → 모델 → 사이즈를 한 화면에서 고른다.
/// 셔터는 견적기로, 그 외는 표준단가로 금액이 바로 나오고 거기서 견적서를 쓴다.
/// 저장한 견적서·작성 중은 위 「견적서」에서 본다.
class QuoterHubScreen extends ConsumerStatefulWidget {
  const QuoterHubScreen({super.key, this.showAppBar = true});

  /// 메인 탭 등 상위 Scaffold 안이면 false.
  final bool showAppBar;

  @override
  ConsumerState<QuoterHubScreen> createState() => _QuoterHubScreenState();
}

class _QuoterHubScreenState extends ConsumerState<QuoterHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider);
      if (user == null) return;
      UsageService.recordTab(
        userId: user.id,
        userName: user.name,
        tabKey: 'quoter',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StandardUnitPriceScreen(
      showAppBar: widget.showAppBar,
      title: '견적',
      showHomeButton: Navigator.of(context).canPop(),
    );
  }
}
