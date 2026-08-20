import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Region r(String sido, String region, String branch) => Region(
    id: '$sido-$region',
    sido: sido,
    region: region,
    manager: 'm',
    branchType: branch,
  );

  final regions = [
    r('경기도', '화성시', '본사'),
    r('경기도', '광주시', '본사'),
    r('서울', '서울', '본사'),
    r('광주', '광주', '전남'),
    r('대구', '대구', '대구'),
    r('대전', '대전', '대전'),
    r('경상북도', '포항시', '대구'),
    r('경상북도', '안동시', '대전'),
    r('강원도', '고성군', '본사'),
    r('경상남도', '고성군', '대구'),
  ];

  test('경기 화성시는 본사', () {
    expect(matchSupportBranchType('경기 화성시 남양읍 현대기아로 202-37', regions), '본사');
  });

  test('서울 주소는 본사', () {
    expect(matchSupportBranchType('서울 강남구 테헤란로 1', regions), '본사');
    expect(matchSupportBranchType('서울특별시 강남구 테헤란로 1', regions), '본사');
  });

  test('광주광역시는 전남, 경기 광주시는 본사', () {
    expect(matchSupportBranchType('광주 북구 임동', regions), '전남');
    expect(matchSupportBranchType('광주광역시 북구 임동', regions), '전남');
    expect(matchSupportBranchType('경기 광주시 경충대로 1', regions), '본사');
  });

  test('경북 시군구로 대구/대전을 가른다', () {
    expect(matchSupportBranchType('경북 포항시 남구', regions), '대구');
    expect(matchSupportBranchType('경상북도 안동시', regions), '대전');
  });

  test('고성군은 시·도로 가른다', () {
    expect(matchSupportBranchType('강원 고성군', regions), '본사');
    expect(matchSupportBranchType('경남 고성군', regions), '대구');
  });

  test('주소 없거나 모르면 기타', () {
    expect(matchSupportBranchType('', regions), '기타');
    expect(matchSupportBranchType('미국 뉴욕', regions), '기타');
  });
}
