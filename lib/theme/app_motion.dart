import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 앱 전역 모션 — 짧고 끊김 없는 체감 속도.
abstract final class AppMotion {
  /// 탭·칩·아이콘 하이라이트
  static const Duration instant = Duration(milliseconds: 90);

  /// 버튼·네비 선택
  static const Duration fast = Duration(milliseconds: 140);

  /// 카드·시트·스위치
  static const Duration normal = Duration(milliseconds: 200);

  /// 화면 전환
  static const Duration page = Duration(milliseconds: 240);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve snap = Curves.easeOutQuart;

  /// 라우트 전환 — 짧은 슬라이드+페이드
  static Route<T> fadeSlideRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: page,
      reverseTransitionDuration: fast,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: snap);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

/// 전역 스크롤 — 바운스·풀 제스처, 부드러운 관성.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
