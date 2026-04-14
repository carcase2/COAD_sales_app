import 'package:coad_customer_calls/core/constants/app_meta.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/sales_calls/sales_call_create_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHubScreen extends ConsumerWidget {
  const HomeHubScreen({super.key, required this.onNavigateToTab});

  final Function(int) onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(todayStatsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── 상단 앱바 ───
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: scheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'COAD Hub',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.primary.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'v$kAppVersion',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
            ],
          ),

          // ─── 본문 영역 ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(user?.name, scheme),
                  const SizedBox(height: 32),

                  // ─── 미니 대시보드 (현황 요약) ───
                  Text(
                    '오늘의 흐름',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    data: (s) => _MiniStatsWidget(
                      today: s.todayCount ?? 0,
                      incomplete: s.incompleteCount ?? 0,
                      onTap: () => onNavigateToTab(1),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // ─── 주요 액션 카드 ───
                  Text(
                    '주요 업무',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),

                  _HubActionCard(
                    title: '최신 상담 현황 확인',
                    subtitle: '오늘 들어온 모든 전화를 한눈에',
                    icon: Icons.assignment_rounded,
                    color: scheme.primary,
                    onTap: () => onNavigateToTab(1),
                  ),
                  const SizedBox(height: 16),

                  _HubActionCard(
                    title: '새로운 상담 등록',
                    subtitle: '빠르고 정확하게 고객 정보 입력',
                    icon: Icons.add_ic_call_rounded,
                    color: scheme.secondary,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SalesCallCreateScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  _HubActionCard(
                    title: '셔터 견적 산출',
                    subtitle: '일반/단열 셔터 정확한 가격 확인',
                    icon: Icons.calculate_rounded,
                    color: Colors.teal.shade600,
                    onTap: () => onNavigateToTab(2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String? name, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${name ?? '사용자'}님,',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '반가워요! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.7),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '오늘도 스마트한 영업을 COAD가 응원합니다.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _MiniStatsWidget extends StatelessWidget {
  const _MiniStatsWidget({
    required this.today,
    required this.incomplete,
    required this.onTap,
  });

  final int today;
  final int incomplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: '금일 접수', value: today.toString(), color: scheme.primary),
            Container(width: 1, height: 40, color: scheme.primary.withValues(alpha: 0.1)),
            _StatItem(label: '미통화', value: incomplete.toString(), color: scheme.error),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color, letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _HubActionCard extends StatefulWidget {
  const _HubActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_HubActionCard> createState() => _HubActionCardState();
}

class _HubActionCardState extends State<_HubActionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
