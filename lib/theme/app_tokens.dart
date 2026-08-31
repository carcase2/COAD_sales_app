import 'package:flutter/material.dart';

/// 앱 전역 시맨틱 컬러·간격 — [ColorScheme] 위에 얹는 토큰.
///
/// 하드코딩 `Colors.red` / `deepOrange` 대신 여기 또는 scheme을 사용합니다.
class AppTokens {
  AppTokens._();

  // ── spacing ──
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;

  // ── radius ──
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusPill = 999;

  // ── touch (테슬라식 한 손 조작 — 넉넉한 타깃) ──
  static const double minTouchTarget = 48;
  static const double primaryCtaHeight = 52;

  // ── motion (AppMotion 과 맞춤 — 짧은 전환) ──
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 200);

  /// 필수 업데이트 칩/배지.
  static Color updateForceBg(ColorScheme scheme) => scheme.error;
  static Color updateForceFg(ColorScheme scheme) => scheme.onError;

  /// 선택 업데이트 칩 (AppBar 위 primary 배경).
  static Color updateOptionalBg(ColorScheme scheme) =>
      Color.lerp(scheme.tertiary, scheme.primary, 0.25)!;
  static Color updateOptionalFg(ColorScheme scheme) =>
      scheme.onPrimary.withValues(alpha: 0.98);

  /// 하단 네비 — 본사일반 일정.
  static Color generalScheduleAccent(ColorScheme scheme) =>
      Color.lerp(scheme.tertiary, scheme.error, 0.35)!;

  /// 하단 네비 — 대구지사 일정 (핑크 톤, COAD_home 과 유사).
  static Color daeguScheduleAccent(ColorScheme scheme) =>
      Color.lerp(const Color(0xFFDB2777), scheme.primary, 0.2)!;

  /// 고객지원팀(AS) — 웹 탭과 같은 틸.
  static Color customerSupportAccent(ColorScheme scheme) =>
      Color.lerp(const Color(0xFF0D9488), scheme.primary, 0.18)!;

  /// 자동문의고수 — 고객지원 틸과 구분되는 바이올렛.
  static Color gosuAccent(ColorScheme scheme) =>
      Color.lerp(const Color(0xFF7C3AED), scheme.primary, 0.1)!;

  /// 메일 발송 — COAD_home mail 탭의 로즈.
  static Color mailAccent(ColorScheme scheme) =>
      Color.lerp(const Color(0xFFE11D48), scheme.primary, 0.12)!;

  /// A/S 지사 필터 — 전체/본사/대구/대전/전남/기타.
  static Color supportBranchAccent(String branch, ColorScheme scheme) {
    switch (branch) {
      case '본사':
        return Color.lerp(const Color(0xFF2563EB), scheme.primary, 0.2)!;
      case '대구':
        return daeguScheduleAccent(scheme);
      case '대전':
        return const Color(0xFFD97706);
      case '전남':
        return const Color(0xFF16A34A);
      case '기타':
        return Color.lerp(scheme.outline, scheme.onSurface, 0.35)!;
      case '전체':
      default:
        return customerSupportAccent(scheme);
    }
  }

  /// 접수 네비.
  static Color receptionAccent(ColorScheme scheme) => scheme.tertiary;

  /// 성공/완료 톤 (칩·토글).
  static Color success(ColorScheme scheme) =>
      Color.lerp(scheme.primary, const Color(0xFF10B981), 0.55)!;

  /// 정보/경로 톤.
  static Color info(ColorScheme scheme) =>
      Color.lerp(scheme.secondary, const Color(0xFF0EA5E9), 0.45)!;
}
