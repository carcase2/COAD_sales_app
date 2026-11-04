import 'package:coad_customer_calls/features/unit_price/size_quote_product_pick.dart';
import 'package:coad_customer_calls/features/unit_price/standard_unit_price_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 견적서에 넣을 제품을 고른다. 견적 화면(분류·모델·사이즈)을 고르기 모드로 열고,
/// 셔터는 견적기 금액, 그 외는 표준단가로 「넣기」/「견적서」를 누르면 돌아온다.
/// [allowManual]이면 먼저 「모델·사이즈로 고르기 / 직접 입력」을 묻는다.
Future<SizeQuoteProductPick?> showQuoteProductPicker(
  BuildContext context, {
  bool allowManual = true,
  String title = '어떤 제품으로 견적을 낼까요?',
}) async {
  if (allowManual) {
    final manual = await showModalBottomSheet<bool>(
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
                icon: Icons.straighten_rounded,
                title: '모델·사이즈로 고르기',
                subtitle: '셔터는 견적기, 스피드도어·차고문은 표준단가로 금액',
                onTap: () => Navigator.pop(ctx, false),
              ),
              _SourceTile(
                icon: Icons.edit_note_rounded,
                title: '직접 입력',
                subtitle: '품명·단가를 손으로 적기',
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (manual == null || !context.mounted) return null;
    HapticFeedback.selectionClick();
    if (manual) return const SizeQuoteProductPick.manual();
  }
  return Navigator.of(context).push<SizeQuoteProductPick>(
    MaterialPageRoute(
      builder: (_) => const StandardUnitPriceScreen(pickMode: true),
    ),
  );
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
