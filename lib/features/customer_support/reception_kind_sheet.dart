enum ReceptionKind { afterSales, sales, gosu }

/// 홈 부서 페이지(0 영업 · 1 고객지원 · 2 자동문의고수) → 접수 탭.
ReceptionKind receptionKindForHomeDeptPage(int pageIndex) {
  return switch (pageIndex) {
    1 => ReceptionKind.afterSales,
    2 => ReceptionKind.gosu,
    _ => ReceptionKind.sales,
  };
}

/// 탭 전환 시에도 작성 중 내용을 잃지 않도록, 임베드된 폼이 등록하는 검사.
class ReceptionUnsavedRegistry {
  final Map<ReceptionKind, bool Function()> _checks = {};

  void register(ReceptionKind kind, bool Function() hasUnsaved) {
    _checks[kind] = hasUnsaved;
  }

  void unregister(ReceptionKind kind) {
    _checks.remove(kind);
  }

  bool get hasAnyUnsaved => _checks.values.any((fn) => fn());
}
