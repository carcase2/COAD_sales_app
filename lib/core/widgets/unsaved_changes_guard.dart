import 'package:flutter/material.dart';

/// 작성 중인 화면에서 뒤로가기를 잘못 눌러 입력이 사라지지 않게 막는다.
///
/// [hasChanges]가 true면 "나가시겠습니까?"를 먼저 묻는다. 저장 버튼처럼 코드에서
/// `Navigator.pop`을 직접 부르는 경로는 막지 않는다 (시스템·앱바 뒤로가기만 대상).
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
    this.message = '작성 중인 내용이 있습니다.\n저장하지 않고 나가시겠습니까?',
  });

  /// 뒤로가기 시점에 호출 — 입력은 rebuild를 일으키지 않으므로 값이 아닌 함수로 받는다.
  final bool Function() hasChanges;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!hasChanges()) {
          navigator.pop();
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('작성 취소'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('계속 작성'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('나가기'),
              ),
            ],
          ),
        );
        if (leave == true && navigator.mounted) navigator.pop();
      },
      child: child,
    );
  }
}
