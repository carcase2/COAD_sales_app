import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';

/// 웹 `src/lib/tempManagerUtils.ts` · `applyCallOverrides` 와 동일 규칙.

bool isTempOverrideActive(TempManagerOverride o, String todayYmd) {
  if (!o.isActive) return false;
  return isYmdWithinInclusiveRange(
    todayYmd,
    startYmd: o.startDate,
    endYmd: o.endDate,
  );
}

bool isTempOverrideExpired(TempManagerOverride o, String todayYmd) {
  if (!o.isActive) return false;
  final end = o.endDate?.trim() ?? '';
  if (end.isEmpty) return false;
  return compareYmd(end, todayYmd) < 0;
}

bool isCallWithinOverridePeriod(
  SalesCall call,
  TempManagerOverride override,
) {
  final ymd = salesCallReceptionYmdForCall(
    callDate: call.callDate,
    callTime: call.callTime,
    createdAt: call.createdAt,
  );
  if (ymd.isEmpty) return true;
  return isYmdWithinInclusiveRange(
    ymd,
    startYmd: override.startDate,
    endYmd: override.endDate,
  );
}

/// 만료된 override — 적용 기간 중 임시 담당 명의 접수 건 DB 원복 대상
bool shouldRevertCallToOriginal(
  SalesCall call,
  TempManagerOverride override,
  String todayYmd,
) {
  if (!isTempOverrideExpired(override, todayYmd)) return false;
  if ((call.regionName ?? '').trim() != override.regionName) return false;
  if (!isCallWithinOverridePeriod(call, override)) return false;

  final temp = override.tempManager.trim();
  final original = override.originalManager.trim();
  if (temp.isEmpty || original.isEmpty) return false;

  final a = (call.assignedTo ?? '').trim();
  return a == temp;
}

/// 웹 `applyCallOverrides` — 기간 중 목록·상세 표시용 (DB 미수정)
List<SalesCall> applyCallDisplayOverrides(
  List<SalesCall> calls,
  List<TempManagerOverride> overrides,
  DateTime nowKst,
) {
  if (overrides.isEmpty) return calls;
  final todayYmd = ymdSeoulFromDateTime(nowKst);

  return calls.map((call) {
    final regionName = (call.regionName ?? '').trim();
    if (regionName.isEmpty) return call;

    TempManagerOverride? active;
    for (final o in overrides) {
      if (!isTempOverrideActive(o, todayYmd)) continue;
      if (o.regionName != regionName) continue;
      active = o;
      break;
    }
    if (active == null) return call;

    final temp = active.tempManager.trim();
    if (temp.isEmpty) return call;

    return SalesCall(
      id: call.id,
      callDate: call.callDate,
      callTime: call.callTime,
      customerName: call.customerName,
      customerPhone: call.customerPhone,
      inquiryContent: call.inquiryContent,
      productCategoryId: call.productCategoryId,
      inquiryMethodId: call.inquiryMethodId,
      regionId: call.regionId,
      statusId: call.statusId,
      assignedTo: temp,
      createdBy: call.createdBy,
      callStage: call.callStage,
      nextScheduledDate: call.nextScheduledDate,
      regionSido: call.regionSido,
      regionName: call.regionName,
      regionManager: call.regionManager,
      regionBranchType: call.regionBranchType,
      createdAt: call.createdAt,
      updatedAt: call.updatedAt,
      productCategoryName: call.productCategoryName,
      inquiryMethodName: call.inquiryMethodName,
      regionLabel: call.regionLabel,
      statusLabel: call.statusLabel,
      callHistory: call.callHistory,
      images: call.images,
    );
  }).toList();
}

/// 목록·필터용 표시 담당자
String displayAssigneeForCall(
  SalesCall call,
  List<TempManagerOverride> overrides,
  DateTime nowKst,
) {
  final applied = applyCallDisplayOverrides([call], overrides, nowKst).first;
  final a = (applied.assignedTo ?? '').trim();
  if (a.isNotEmpty) return a;
  return '미지정';
}

/// 기간 중 “임시 담당 변경” 여부 및 상세 정보를 찾는다.
/// - 목록/상세 표시용: DB 저장은 `assigned_to`만 사용한다.
/// - `SalesCall.assignedTo`는 이미 오버레이가 적용된 값일 수 있어,
///   매칭 기준은 `temp_manager`(=변경 후) 및 `original_manager`(=변경 전) 모두 허용한다.
TempManagerOverride? findActiveTempOverrideForCall(
  SalesCall call,
  List<TempManagerOverride> overrides,
  DateTime nowKst,
) {
  if (overrides.isEmpty) return null;
  final todayYmd = ymdSeoulFromDateTime(nowKst);

  final regionName = (call.regionName ?? '').trim();
  if (regionName.isEmpty) return null;

  final assigned = (call.assignedTo ?? '').trim();
  final original = (call.regionManager ?? '').trim();

  for (final o in overrides) {
    if (!isTempOverrideActive(o, todayYmd)) continue;
    if (o.regionName.trim() != regionName) continue;

    final oOriginal = o.originalManager.trim();
    final oTemp = o.tempManager.trim();
    if (oTemp.isEmpty || oOriginal.isEmpty) continue;

    // (1) 이미 오버레이가 적용된 경우: assigned_to == temp_manager
    if (assigned.isNotEmpty && assigned == oTemp) return o;

    // (2) 오버레이 미적용/레거시: assigned_to == original_manager
    if (assigned.isNotEmpty && assigned == oOriginal) return o;

    // (3) 지역 원담당(=DB region_manager)을 기준으로 매칭
    if (original.isNotEmpty && original == oOriginal) return o;
  }

  return null;
}
