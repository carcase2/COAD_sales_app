import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';

/// 발급 탭 공통 비주얼 — [ColorScheme] 기반, 홈 허브와 톤을 맞춤.
class IssuanceVisual {
  IssuanceVisual._();

  static Color domainAccent(IssuanceDomain domain, ColorScheme scheme) =>
      switch (domain) {
        IssuanceDomain.taxInvoice => scheme.primary,
        IssuanceDomain.performanceBond => scheme.tertiary,
      };

  static Color navAccent(ColorScheme scheme) =>
      Color.lerp(scheme.primary, scheme.secondary, 0.45)!;

  static BoxDecoration hubHeader(IssuanceDomain domain, ColorScheme scheme) {
    final accent = domainAccent(domain, scheme);
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          accent,
          Color.lerp(accent, scheme.surface, 0.22)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.1),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  static BoxDecoration menuTile(ColorScheme scheme) => BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      );

  static Color pendingTileAccent(ColorScheme scheme) => scheme.primary;

  static Color todayTileAccent(ColorScheme scheme) => scheme.secondary;

  static Color partialTileAccent(ColorScheme scheme) => scheme.tertiary;

  static Color completedTileAccent(ColorScheme scheme) =>
      Color.lerp(scheme.secondary, scheme.primary, 0.35)!;

  static Color cancelledTileAccent(ColorScheme scheme) => scheme.outline;

  static String domainLabel(IssuanceDomain domain) => switch (domain) {
        IssuanceDomain.taxInvoice => '세금계산서',
        IssuanceDomain.performanceBond => '이행증권',
      };
}

String issuanceCountLabel(int? count) => count == null ? '…' : '$count';
