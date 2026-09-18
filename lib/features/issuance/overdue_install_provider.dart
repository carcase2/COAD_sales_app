import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/overdue_install_repository.dart';
import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final overdueInstallRepositoryProvider = Provider<OverdueInstallRepository>((
  ref,
) {
  return OverdueInstallRepository();
});

/// 오늘 이전 · 시공완료 안 된 현장 (최근 2년).
final overduePendingRowsProvider = FutureProvider<List<OverdueInstallSite>>((
  ref,
) async {
  final today = todayYmdSeoul();
  final window = overdueInstallLookbackRange(today);
  return ref
      .read(overdueInstallRepositoryProvider)
      .fetchPendingOverdue(
        fromYmd: window.from,
        toYmd: window.to,
        todayYmd: today,
      );
});
