import 'package:coad_customer_calls/models/region.dart';

const kSupportBranchTabOrder = ['전체', '본사', '대구', '대전', '전남', '기타'];

const _sidoAliases = <String, List<String>>{
  '서울': ['서울특별시', '서울시', '서울'],
  '부산': ['부산광역시', '부산시', '부산'],
  '대구': ['대구광역시', '대구시', '대구'],
  '인천': ['인천광역시', '인천시', '인천'],
  '광주': ['광주광역시', '광주시', '광주'],
  '대전': ['대전광역시', '대전시', '대전'],
  '울산': ['울산광역시', '울산시', '울산'],
  '세종': ['세종특별자치시', '세종시', '세종'],
  '경기도': ['경기도', '경기'],
  '강원도': ['강원특별자치도', '강원도', '강원'],
  '충청북도': ['충청북도', '충북'],
  '충청남도': ['충청남도', '충남'],
  '전라북도': ['전북특별자치도', '전라북도', '전북'],
  '전라남도': ['전라남도', '전남'],
  '경상북도': ['경상북도', '경북'],
  '경상남도': ['경상남도', '경남'],
  '제주도': ['제주특별자치도', '제주도', '제주'],
  '기타': ['기타'],
  '해외': ['해외'],
};

/// 주소에서 regions.sido/region을 가장 길게 맞춰 branch_type을 고른다.
String matchSupportBranchType(String address, List<Region> regions) {
  final addr = address.trim();
  if (addr.isEmpty || regions.isEmpty) return '기타';

  var bestScore = 0;
  final bestTypes = <String>{};

  for (final row in regions) {
    final type = (row.branchType ?? '').trim();
    if (type.isEmpty) continue;
    final score = _scoreRegion(addr, row);
    if (score <= 0) continue;
    if (score > bestScore) {
      bestScore = score;
      bestTypes
        ..clear()
        ..add(type);
    } else if (score == bestScore) {
      bestTypes.add(type);
    }
  }

  if (bestTypes.length == 1) return bestTypes.first;
  return '기타';
}

int _scoreRegion(String address, Region row) {
  final regionName = row.region.trim();
  final sido = row.sido.trim();
  if (regionName.isEmpty && sido.isEmpty) return 0;

  final sidoHit = _containsSido(address, sido);
  final regionHit = regionName.isNotEmpty && address.contains(regionName);

  // 서울/광주처럼 시·도가 한 줄인 마스터
  if (regionName == sido) {
    return sidoHit ? 20 + sido.length : 0;
  }

  if (regionHit) {
    var score = 100 + regionName.length;
    if (sidoHit) score += 40;
    return score;
  }
  return 0;
}

bool _containsSido(String address, String sido) {
  final aliases = _sidoAliases[sido] ?? [sido];
  for (final alias in aliases) {
    if (alias.isEmpty) continue;
    if (address.contains(alias)) return true;
  }
  return false;
}

String supportBranchTabOf(String address, List<Region> regions) {
  final type = matchSupportBranchType(address, regions);
  return kSupportBranchTabOrder.contains(type) ? type : '기타';
}

/// 전체 · 본사 · 대구 · 대전 · 전남 · 기타 건수. 탭에 없는 지사는 기타로 넣는다.
Map<String, int> supportBranchCounts(
  Iterable<String> addresses,
  List<Region> regions,
) {
  final counts = {for (final tab in kSupportBranchTabOrder) tab: 0};
  var total = 0;
  for (final address in addresses) {
    total += 1;
    final tab = supportBranchTabOf(address, regions);
    counts[tab] = (counts[tab] ?? 0) + 1;
  }
  counts['전체'] = total;
  return counts;
}
