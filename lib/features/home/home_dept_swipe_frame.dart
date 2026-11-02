import 'package:flutter/material.dart';

/// 홈 흐름 탭의 부서 페이지(영업부 · 고객지원팀 · 자동문의고수) 넘김 프레임.
///
/// 화살표는 페이지 내용 위에 겹치지 않는다.
/// 페이저 너비가 [narrowBreakpoint] 미만이면 화살표를 숨기고 스와이프만 남긴다.
/// 그 이상이면 좌우 [laneWidth] 레일에 작은 반투명 화살표를 두고,
/// 페이지 내용은 레일 안쪽에만 그린다.
class HomeDeptSwipeFrame extends StatelessWidget {
  const HomeDeptSwipeFrame({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.pageLabels,
    required this.onGoTo,
    required this.accentFor,
    required this.child,
  });

  /// 이 너비보다 좁으면 오버레이 화살표를 그리지 않는다.
  static const double narrowBreakpoint = 400;

  /// 화살표 레일 너비. 페이지 내용은 이 너비만큼 안쪽에 놓인다.
  static const double laneWidth = 32;

  final int pageIndex;
  final int pageCount;
  final List<String> pageLabels;
  final ValueChanged<int> onGoTo;
  final Color Function(int index) accentFor;
  final Widget child;

  bool get _showPrevious => pageIndex > 0;

  bool get _showNext => pageIndex < pageCount - 1;

  String _labelAt(int index) {
    if (index < 0 || index >= pageLabels.length) return '';
    return pageLabels[index];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showArrows = constraints.maxWidth >= narrowBreakpoint;
        final lane = showArrows ? laneWidth : 0.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(left: lane, right: lane, child: child),
            if (showArrows && _showPrevious)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: lane,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _DeptSwipeArrow(
                    tooltip: _labelAt(pageIndex - 1),
                    icon: Icons.chevron_left_rounded,
                    foreground: accentFor(pageIndex - 1),
                    background: scheme.surface.withValues(alpha: 0.42),
                    onPressed: () => onGoTo(pageIndex - 1),
                  ),
                ),
              ),
            if (showArrows && _showNext)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: lane,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _DeptSwipeArrow(
                    tooltip: _labelAt(pageIndex + 1),
                    icon: Icons.chevron_right_rounded,
                    foreground: accentFor(pageIndex + 1),
                    background: scheme.surface.withValues(alpha: 0.42),
                    onPressed: () => onGoTo(pageIndex + 1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DeptSwipeArrow extends StatelessWidget {
  const _DeptSwipeArrow({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;

  static const double _width = 24;
  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: _width,
              height: _height,
              child: Icon(
                icon,
                size: 18,
                color: foreground.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
