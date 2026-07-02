import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 조회 시작일(과거 이력 하한) — 기본은 오늘 기준 [kGeneralScheduleHistoryDays]일 전.
/// 날짜 스트립·달력에서 더 과거로 이동하면 화면이 이 값을 앞당겨 재조회한다.
const int kGeneralScheduleHistoryDays = 62;

String defaultGeneralScheduleWindowStart() =>
    addDaysToYmd(todayYmdSeoul(), -kGeneralScheduleHistoryDays);

final generalScheduleWindowStartProvider =
    StateProvider<String>((ref) => defaultGeneralScheduleWindowStart());

final generalScheduleRecordsProvider =
    FutureProvider.autoDispose<List<GeneralScheduleRecord>>((ref) async {
  final repo = ref.watch(generalScheduleRepositoryProvider);
  final windowStart = ref.watch(generalScheduleWindowStartProvider);
  return repo.fetchAll(endDateFromYmd: windowStart);
});

final generalScheduleGridProvider =
    Provider.autoDispose<GeneralScheduleDayGrid>((ref) {
  final records = ref.watch(generalScheduleRecordsProvider).valueOrNull ?? [];
  return buildGeneralScheduleGrid(records);
});

final generalScheduleDoorTypesProvider =
    FutureProvider.autoDispose<List<DoorTypeOption>>((ref) async {
  final repo = ref.watch(generalScheduleRepositoryProvider);
  return repo.fetchDoorTypes();
});

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