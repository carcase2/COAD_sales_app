import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/schedule_branch.dart';
import 'package:coad_customer_calls/data/general_schedule_repository.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 조회 시작일(과거 이력 하한) — 기본은 오늘 기준 [kGeneralScheduleHistoryDays]일 전.
/// 날짜 스트립·달력에서 더 과거로 이동하면 화면이 이 값을 앞당겨 재조회한다.
const int kGeneralScheduleHistoryDays = 62;

String defaultGeneralScheduleWindowStart() =>
    addDaysToYmd(todayYmdSeoul(), -kGeneralScheduleHistoryDays);

final scheduleRepositoryProvider =
    Provider.family<GeneralScheduleRepository, ScheduleBranch>((ref, branch) {
  return GeneralScheduleRepository(
    ref.watch(appDependenciesProvider),
    branch: branch,
  );
});

final scheduleWindowStartProvider =
    StateProvider.family<String, ScheduleBranch>((ref, branch) {
  return defaultGeneralScheduleWindowStart();
});

final scheduleRecordsProvider = FutureProvider.autoDispose
    .family<List<GeneralScheduleRecord>, ScheduleBranch>((ref, branch) async {
  final repo = ref.watch(scheduleRepositoryProvider(branch));
  final windowStart = ref.watch(scheduleWindowStartProvider(branch));
  return repo.fetchAll(endDateFromYmd: windowStart);
});

final scheduleGridProvider =
    Provider.autoDispose.family<GeneralScheduleDayGrid, ScheduleBranch>((
  ref,
  branch,
) {
  final records =
      ref.watch(scheduleRecordsProvider(branch)).valueOrNull ?? [];
  return buildGeneralScheduleGrid(records);
});

/// door_types 는 본사·대구 공용 마스터.
final scheduleDoorTypesProvider =
    FutureProvider.autoDispose.family<List<DoorTypeOption>, ScheduleBranch>((
  ref,
  branch,
) async {
  final repo = ref.watch(scheduleRepositoryProvider(branch));
  return repo.fetchDoorTypes();
});

// ── 본사일반 호환 별칭 ──────────────────────────────────────────

final generalScheduleWindowStartProvider = scheduleWindowStartProvider(
  ScheduleBranch.headOffice,
);

final generalScheduleRecordsProvider =
    scheduleRecordsProvider(ScheduleBranch.headOffice);

final generalScheduleGridProvider =
    scheduleGridProvider(ScheduleBranch.headOffice);

final generalScheduleDoorTypesProvider =
    scheduleDoorTypesProvider(ScheduleBranch.headOffice);

GeneralScheduleRecord? findGeneralScheduleById(
  List<GeneralScheduleRecord> records,
  String id,
) {
  for (final r in records) {
    if (r.id == id) return r;
  }
  return null;
}

/// 해당 월(yyyy-MM) 날짜별 점유 칸 수.
Map<String, int> occupancyByDateInMonth(
  GeneralScheduleDayGrid grid,
  int year,
  int month,
) {
  final prefix = '$year-${month.toString().padLeft(2, '0')}-';
  final out = <String, int>{};
  for (final entry in grid.entries) {
    if (!entry.key.startsWith(prefix)) continue;
    out[entry.key] = occupiedSlotCount(grid, entry.key);
  }
  return out;
}

/// FCM 탭 시 본사일반 화면 열기.
final pendingGeneralScheduleLaunchProvider = StateProvider<bool>((ref) => false);

/// FCM 탭 시 대구지사 화면 열기 (향후 FCM 연동용).
final pendingDaeguScheduleLaunchProvider = StateProvider<bool>((ref) => false);
