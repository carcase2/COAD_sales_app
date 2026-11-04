import 'package:coad_customer_calls/features/quoter/quoter_screen.dart';
import 'package:coad_customer_calls/features/unit_price/size_quote_product_pick.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 견적서에 넣을 제품을 고른다: 표준단가 모델 · 셔터 산출 · 직접 입력.
/// 표준단가·셔터는 그 화면을 고르기 모드로 열고, 「견적서」를 누르면 돌아온다.
/// [allowManual]이 false면 직접 입력은 빼고(이미 견적서 안에서 줄 추가가 되므로).
Future<SizeQuoteProductPick?> showQuoteProductPicker(
  BuildContext context, {
  bool allowManual = true,
  String title = '어떤 제품으로 견적을 낼까요?',
}) async {
  final source = await showModalBottomSheet<SizeQuoteProductSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _SourceTile(
              icon: Icons.grid_on_rounded,
              title: '표준단가 모델',
              subtitle: '자동문·스피드도어 등 · 모델과 사이즈로 단가',
              onTap: () => Navigator.pop(ctx, SizeQuoteProductSource.standard),
            ),
            _SourceTile(
              icon: Icons.calculate_rounded,
              title: '셔터 산출',
              subtitle: '셔터 견적기로 종류·규격을 넣어 계산',
              onTap: () => Navigator.pop(ctx, SizeQuoteProductSource.shutter),
            ),
            if (allowManual)
              _SourceTile(
                icon: Icons.edit_note_rounded,
                title: '직접 입력',
                subtitle: '품명·단가를 손으로 적기',
                onTap: () => Navigator.pop(ctx, SizeQuoteProductSource.manual),
              ),
          ],
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  HapticFeedback.selectionClick();
  switch (source) {
    case SizeQuoteProductSource.manual:
      return const SizeQuoteProductPick.manual();
    case SizeQuoteProductSource.standard:
      return Navigator.of(context).push<SizeQuoteProductPick>(
        MaterialPageRoute(
          builder: (_) => const StandardUnitPriceScreen(pickMode: true),
        ),
      );
    case SizeQuoteProductSource.shutter:
      return Navigator.of(context).push<SizeQuoteProductPick>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(title: const Text('셔터 산출해서 넣기'), toolbarHeight: 48),
            body: const QuoterScreen(showQuickActions: false, pickMode: true),
          ),
        ),
      );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
