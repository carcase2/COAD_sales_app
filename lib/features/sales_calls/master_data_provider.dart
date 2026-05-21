import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 원본 regions
final regionsRawProvider = FutureProvider<List<Region>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchRegions();
});

/// 임시 담당자 오버라이드 (항상 최신 기준)
final tempManagerOverridesProvider =
    FutureProvider<List<TempManagerOverride>>((ref) async {
      final repo = ref.watch(salesCallsRepositoryProvider);
      await repo.revertExpiredTempManagerCalls();
      return repo.fetchTempOverrides();
    });

/// regions + overrides 합성 결과 (effective manager)
final effectiveRegionsProvider = FutureProvider<List<Region>>((ref) async {
  final regions = await ref.watch(regionsRawProvider.future);
  final overrides = await ref.watch(tempManagerOverridesProvider.future);
  return SalesCallsRepository.buildEffectiveRegions(regions, overrides, DateTime.now());
});

final masterDataProvider = FutureProvider<MasterDataBundle>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchMasterData();
});

/// 신규 등록 화면 전용 마스터:
/// product/method는 master_data를 사용하고,
/// regions는 effectiveRegionsProvider 결과를 강제로 주입한다.
final salesCallCreateMasterDataProvider = FutureProvider<MasterDataBundle>((
  ref,
) async {
  final master = await ref.watch(masterDataProvider.future);
  final effectiveRegions = await ref.watch(effectiveRegionsProvider.future);
  return MasterDataBundle(
    productCategories: master.productCategories,
    inquiryMethods: master.inquiryMethods,
    regions: effectiveRegions
        .map((e) => NamedMasterRow.fromJson(e.toMasterRowJson()))
        .toList(),
  );
});
