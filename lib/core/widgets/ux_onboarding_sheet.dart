import 'package:coad_customer_calls/core/constants/ux_prefs.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 첫 로그인 후 한 번만 표시하는 사용 안내.
Future<void> showUxOnboardingIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final prefs = ref.read(appDependenciesProvider).prefs;
  if (prefs.getBool(UxPrefs.onboardingSeen) == true) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'COAD 영업 사용 안내',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '현장 한 손 조작에 맞춰 설계했습니다.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _OnboardingRow(
                icon: Icons.add_ic_call_rounded,
                color: scheme.tertiary,
                title: '접수 (큰 버튼)',
                body: '하단 가운데 큰 「접수」를 누르면 바로 등록. 길게 누르면 오늘 목록·미통화 메뉴.',
              ),
              const SizedBox(height: 12),
              _OnboardingRow(
                icon: Icons.phone_missed_rounded,
                color: scheme.error,
                title: '지금 할 일',
                body: '홈 상단 「지금 처리」로 미통화를 바로 엽니다. 목록에서는 녹색 전화 버튼으로 즉시 통화.',
              ),
              const SizedBox(height: 12),
              _OnboardingRow(
                icon: Icons.search_rounded,
                color: scheme.primary,
                title: '통합 검색',
                body: '상단 돋보기로 전화번호·현장명·상담내용을 검색합니다.',
              ),
              const SizedBox(height: 12),
              _OnboardingRow(
                icon: Icons.touch_app_rounded,
                color: scheme.secondary,
                title: '홈 통계 · 상세',
                body: '통계 카드 길게 누르기 = 담당자 선택. 상세 화면 하단에서 전화·문자·상담 입력.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('시작하기'),
              ),
            ],
          ),
        ),
      );
    },
  );

  await prefs.setBool(UxPrefs.onboardingSeen, true);
}

class _OnboardingRow extends StatelessWidget {
  const _OnboardingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
