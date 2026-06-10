import 'package:flutter/material.dart';

/// Supabase/네트워크 예외를 사용자용 한글 메시지로 변환.
String issuanceUserErrorMessage(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network')) {
    return '네트워크 연결을 확인해 주세요.';
  }
  if (lower.contains('timeout')) {
    return '요청 시간이 초과되었습니다. 다시 시도해 주세요.';
  }
  if (lower.contains('401') || lower.contains('jwt')) {
    return '로그인이 만료되었습니다. 다시 로그인해 주세요.';
  }
  if (lower.contains('permission') || lower.contains('row-level security')) {
    return '저장 권한이 없습니다. 관리자에게 문의해 주세요.';
  }
  if (error is Exception) {
    final msg = raw.replaceFirst('Exception: ', '').trim();
    if (msg.isNotEmpty && !msg.startsWith('Instance of')) return msg;
  }
  return '처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}

/// 취소 사유 입력 다이얼로그. 확인 시 사유 문자열, 취소 시 null.
Future<String?> showIssuanceCancelDialog(
  BuildContext context, {
  required String targetName,
}) async {
  final controller = TextEditingController();
  String? validationError;

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('발급요청 취소'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('「$targetName」 발급요청을 취소합니다.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: '취소 사유 *',
                    hintText: '취소 사유를 입력해 주세요.',
                    errorText: validationError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('닫기'),
              ),
              FilledButton(
                onPressed: () {
                  final reason = controller.text.trim();
                  if (reason.isEmpty) {
                    setDialogState(
                      () => validationError = '취소 사유를 입력해 주세요.',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(reason);
                },
                child: const Text('취소 처리'),
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
  return result;
}

/// AppBar 새로고침 버튼용 — 진행 중이면 스피너, 아니면 새로고침 아이콘.
Widget issuanceRefreshButtonIcon({
  required bool loading,
  double size = 24,
  Color? color,
}) {
  if (!loading) {
    return Icon(Icons.refresh_rounded, size: size, color: color);
  }
  return SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: color,
    ),
  );
}

/// 새로고침 실행 + 로딩 상태·완료/실패 스낵바.
Future<void> runIssuanceRefresh({
  required BuildContext context,
  required Future<void> Function() action,
  required void Function(bool loading) onLoadingChanged,
  bool showCompletionSnackBar = true,
}) async {
  onLoadingChanged(true);
  try {
    await action();
    if (!context.mounted) return;
    if (showCompletionSnackBar) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('새로고침 완료'),
            duration: Duration(milliseconds: 1600),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  } catch (e) {
    if (!context.mounted) return;
    // 에러는 스낵바로 안내 완료 — 호출부(onPressed 등)에서 await하지 않으므로
    // rethrow하면 unhandled async exception이 된다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(issuanceUserErrorMessage(e))),
      );
  } finally {
    if (context.mounted) onLoadingChanged(false);
  }
}
