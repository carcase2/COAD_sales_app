import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/issuance/issuance_list_kind.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 알림 deep link용 — master/issue id로 발급 행 검색.
IssuanceRequestRow? findIssuanceRowByIds(
  List<IssuanceRequestRow> rows, {
  required String masterId,
  String? issueId,
}) {
  final mid = masterId.trim();
  if (mid.isEmpty) return null;
  final iid = issueId?.trim() ?? '';
  IssuanceRequestRow? fallback;
  for (final row in rows) {
    if (row.master['id']?.toString() != mid) continue;
    fallback ??= row;
    if (iid.isNotEmpty) {
      if (row.issue?['id']?.toString() == iid) return row;
    } else {
      return row;
    }
  }
  return fallback;
}

IssuanceListKind issuanceListKindForRow(IssuanceRequestRow row) {
  return switch (row.kind) {
    IssuanceRowKind.request => IssuanceListKind.request,
    IssuanceRowKind.partial => IssuanceListKind.partial,
    IssuanceRowKind.completed || IssuanceRowKind.issued =>
      IssuanceListKind.fullyCompleted,
    IssuanceRowKind.cancelled => IssuanceListKind.cancelled,
  };
}

/// Supabase/네트워크 예외를 사용자용 한글 메시지로 변환.
String issuanceUserErrorMessage(Object error) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty &&
        message.toLowerCase() != 'bad request' &&
        !message.startsWith('{')) {
      return message;
    }
  }
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

class IssuanceSearchField extends StatelessWidget {
  const IssuanceSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = '현장명·업체명·번호 검색',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '지우기',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// 발급완료·발급일 기준 `yyyy-MM-dd` (없으면 요청일 서울 기준).
String issuanceIssueYmdForRow(IssuanceRequestRow row) {
  for (final raw in [row.issue?['issue_date'], row.master['issue_date']]) {
    if (raw == null) continue;
    final s = raw.toString().trim();
    if (s.length >= 10) return s.substring(0, 10);
  }
  return ymdSeoulFromDateTime(row.createdAt);
}

bool issuanceIsTodayIssuedRow(IssuanceRequestRow row) =>
    issuanceIssueYmdForRow(row) == todayYmdSeoul();

/// 목록 오류 시 당겨서 새로고침 + 다시 시도.
Widget issuanceListErrorScrollable({
  required String message,
  required VoidCallback onRetry,
}) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 120),
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// 취소 사유 입력 다이얼로그. 확인 시 사유 문자열, 취소 시 null.
Future<String?> showIssuanceCancelDialog(
  BuildContext context, {
  required String targetName,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _IssuanceCancelDialog(targetName: targetName);
    },
  );
}

class _IssuanceCancelDialog extends StatefulWidget {
  const _IssuanceCancelDialog({required this.targetName});

  final String targetName;

  @override
  State<_IssuanceCancelDialog> createState() => _IssuanceCancelDialogState();
}

class _IssuanceCancelDialogState extends State<_IssuanceCancelDialog> {
  final _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('발급요청 취소'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('「${widget.targetName}」 발급요청을 취소합니다.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '취소 사유 *',
              hintText: '취소 사유를 입력해 주세요.',
              errorText: _validationError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _controller.text.trim();
            if (reason.isEmpty) {
              setState(() => _validationError = '취소 사유를 입력해 주세요.');
              return;
            }
            Navigator.of(context).pop(reason);
          },
          child: const Text('취소 처리'),
        ),
      ],
    );
  }
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

/// 발급 허브·배지·목록 공통 캐시 무효화.
void invalidateIssuanceCore(WidgetRef ref) {
  for (final domain in IssuanceDomain.values) {
    ref.invalidate(issuanceAllRowsProvider(domain));
    ref.invalidate(issuanceRequestRowsProvider(domain));
    ref.invalidate(issuancePendingCountProvider(domain));
    ref.invalidate(issuanceCancelledRowsProvider(domain));
  }
  ref.invalidate(issuanceRequestBadgeCountProvider);
  ref.invalidate(issuanceRequestTotalBadgeCountProvider);
}

/// Realtime 백그라운드 갱신용 — 경량 배지·pending 카운트만 무효화.
/// 발급 탭에 있지 않을 때 전체 목록 refetch를 피합니다.
void invalidateIssuanceBadgeOnly(WidgetRef ref) {
  ref.invalidate(issuanceRequestBadgeCountProvider);
  ref.invalidate(issuanceRequestTotalBadgeCountProvider);
  for (final domain in IssuanceDomain.values) {
    ref.invalidate(issuancePendingCountProvider(domain));
  }
}

/// 허브 첫 화면용 — 경량 pending 카운트만 다시 불러옴.
Future<void> refreshIssuanceHubSummary(WidgetRef ref) async {
  await Future.wait([
    ref.read(issuancePendingCountProvider(IssuanceDomain.taxInvoice).future),
    ref.read(issuancePendingCountProvider(IssuanceDomain.performanceBond).future),
  ]);
}
