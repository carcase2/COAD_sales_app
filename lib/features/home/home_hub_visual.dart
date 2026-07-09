import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:flutter/material.dart';

/// 홈 허브 화면 공통 비주얼 — 채도·그라데이션을 줄이고 surface 톤으로 통일.
class HomeHubVisual {
  HomeHubVisual._();

  static ({Color canvas, Color accent}) sectionTone(
    HomeHubSection section,
    ColorScheme scheme,
  ) =>
      switch (section) {
        HomeHubSection.flow => (
            canvas: Color.lerp(scheme.surface, scheme.primaryContainer, 0.07)!,
            accent: scheme.primary,
          ),
        HomeHubSection.calendar => (
            canvas:
                Color.lerp(scheme.surface, scheme.secondaryContainer, 0.12)!,
            accent: scheme.secondary,
          ),
      };

  static BoxDecoration screenBackground(
    HomeHubSection section,
    ColorScheme scheme,
  ) {
    final tone = sectionTone(section, scheme);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [tone.canvas, scheme.surface],
        stops: const [0.0, 0.38],
      ),
    );
  }

  static BoxDecoration header(ColorScheme scheme) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.primaryContainer, 0.22)!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  static BoxDecoration elevatedCard(ColorScheme scheme) => BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
}
