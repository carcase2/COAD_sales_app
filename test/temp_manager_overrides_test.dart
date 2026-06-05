import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Region baseRegion({String manager = 'A'}) => Region(
        id: 'r1',
        sido: '서울',
        region: '강남구',
        manager: manager,
        branchType: '직영',
      );

  TempManagerOverride override({
    bool isActive = true,
    String originalManager = 'A',
    String tempManager = 'B',
    String? startDate,
    String? endDate,
    String regionName = '강남구',
  }) {
    return TempManagerOverride(
      id: 'o1',
      regionName: regionName,
      originalManager: originalManager,
      tempManager: tempManager,
      isActive: isActive,
      startDate: startDate,
      endDate: endDate,
    );
  }

  final now = DateTime(2026, 5, 20);

  test('오버라이드 없음 -> 원담당 저장', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      const [],
      now,
    );
    expect(regions.first.resolvedManager, 'A');
    expect(regions.first.isManagerOverridden, false);
  });

  test('오버라이드 기간 내 -> 임시담당 저장', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [
        override(
          startDate: '2026-05-01',
          endDate: '2026-05-31',
          tempManager: 'B',
        ),
      ],
      now,
    );
    expect(regions.first.resolvedManager, 'B');
    expect(regions.first.resolvedOriginalManager, 'A');
    expect(regions.first.isManagerOverridden, true);
  });

  test('start_date 미래 -> 원담당', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [override(startDate: '2026-06-01', endDate: '2026-06-30')],
      now,
    );
    expect(regions.first.resolvedManager, 'A');
    expect(regions.first.isManagerOverridden, false);
  });

  test('end_date 지난 경우 -> 원담당', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [override(startDate: '2026-04-01', endDate: '2026-05-01')],
      now,
    );
    expect(regions.first.resolvedManager, 'A');
    expect(regions.first.isManagerOverridden, false);
  });

  test('region_name 같아도 original_manager 다르면 미적용', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [override(originalManager: 'C', tempManager: 'B')],
      now,
    );
    expect(regions.first.resolvedManager, 'A');
    expect(regions.first.isManagerOverridden, false);
  });

  test('is_active false면 미적용', () {
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [override(isActive: false, tempManager: 'B')],
      now,
    );
    expect(regions.first.resolvedManager, 'A');
    expect(regions.first.isManagerOverridden, false);
  });

  test('UTC 시간이 KST 다음날이면 KST 날짜로 적용', () {
    final nowUtc = DateTime.utc(2026, 5, 20, 16, 0, 0);
    final regions = SalesCallsRepository.buildEffectiveRegions(
      [baseRegion(manager: 'A')],
      [
        override(
          startDate: '2026-05-21',
          endDate: '2026-05-21',
          tempManager: 'B',
        ),
      ],
      nowUtc,
    );
    expect(regions.first.resolvedManager, 'B');
    expect(regions.first.isManagerOverridden, true);
  });

  test('기간 중 목록 표시 — DB가 원담당이어도 임시 담당으로 오버레이', () {
    final call = SalesCall(
      id: 'c1',
      regionName: '강남구',
      regionManager: 'A',
      assignedTo: 'A',
    );
    final displayed = applyCallDisplayOverrides(
      [call],
      [
        override(
          startDate: '2026-05-01',
          endDate: '2026-05-31',
          tempManager: 'B',
        ),
      ],
      now,
    ).first;
    expect(displayed.regionManager, 'A');
    expect(displayed.assignedTo, 'B');
  });

  test('기간 만료 후 — 오버레이 없음, DB 원담당 그대로 표시', () {
    final call = SalesCall(
      id: 'c1',
      regionName: '강남구',
      regionManager: 'A',
      assignedTo: 'A',
      callDate: '2026-05-05',
    );
    final displayed = applyCallDisplayOverrides(
      [call],
      [
        override(
          startDate: '2026-04-01',
          endDate: '2026-05-01',
          tempManager: 'B',
        ),
      ],
      now,
    ).first;
    expect(displayed.regionManager, 'A');
    expect(displayed.assignedTo, 'A');
  });

  test('만료 후 임시 담당 DB 잔존 건 — shouldRevert 대상', () {
    final call = SalesCall(
      id: 'c1',
      regionName: '강남구',
      regionManager: 'B',
      assignedTo: 'B',
      callDate: '2026-04-15',
    );
    expect(
      shouldRevertCallToOriginal(
        call,
        override(
          startDate: '2026-04-01',
          endDate: '2026-05-01',
          tempManager: 'B',
        ),
        '2026-05-20',
      ),
      isTrue,
    );
  });

  test('기간 밖 접수 건 — shouldRevert 제외', () {
    final call = SalesCall(
      id: 'c1',
      regionName: '강남구',
      regionManager: 'B',
      assignedTo: 'B',
      callDate: '2026-04-20',
    );
    expect(
      shouldRevertCallToOriginal(
        call,
        override(
          startDate: '2026-05-01',
          endDate: '2026-05-31',
          tempManager: 'B',
        ),
        '2026-06-01',
      ),
      isFalse,
    );
  });
}
