import 'package:flutter/material.dart';

/// 발급요청 메뉴별 전용 목록 화면 구분.
enum IssuanceListKind { request, partial, fullyCompleted, all, cancelled }

extension IssuanceListKindMeta on IssuanceListKind {
  String get title => switch (this) {
    IssuanceListKind.request => '발급대기',
    IssuanceListKind.partial => '부분발급',
    IssuanceListKind.fullyCompleted => '완료',
    IssuanceListKind.all => '전체',
    IssuanceListKind.cancelled => '취소',
  };

  String get subtitle => switch (this) {
    IssuanceListKind.request => '미발급 발급요청 건',
    IssuanceListKind.partial => '일부 발급 후 남은 건 (세금계산서)',
    IssuanceListKind.fullyCompleted => '100% 발급 완료 (세금계산서)',
    IssuanceListKind.all => '진행 중인 모든 발급 건',
    IssuanceListKind.cancelled => '취소 처리된 발급요청',
  };

  IconData get icon => switch (this) {
    IssuanceListKind.request => Icons.pending_actions_rounded,
    IssuanceListKind.partial => Icons.pie_chart_outline_rounded,
    IssuanceListKind.fullyCompleted => Icons.task_alt_rounded,
    IssuanceListKind.all => Icons.list_alt_rounded,
    IssuanceListKind.cancelled => Icons.cancel_outlined,
  };
}
