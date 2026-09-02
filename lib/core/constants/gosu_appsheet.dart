/// 자동문의고수 AppSheet·웹(`coad_home`)과 동일한 분류·문의방법·문의종류.
const String kGosuGroupName = '자동문의고수';
const String kGosuProgressOpen = '진행중';
const String kGosuProgressClosed = '종료';
const String kGosuStatusReceived = '접수';
const String kGosuInquiryKindDefault = '단순문의';

class GosuNamedOption {
  const GosuNamedOption({
    required this.id,
    required this.name,
    this.colorHex,
  });

  final int id;
  final String name;
  final String? colorHex;
}

const List<GosuNamedOption> kGosuProductCategories = [
  GosuNamedOption(id: 9101, name: '정보방', colorHex: '#0f766e'),
  GosuNamedOption(id: 9102, name: '슬라이딩AS방', colorHex: '#0369a1'),
  GosuNamedOption(id: 9103, name: '렌탈방', colorHex: '#7c3aed'),
  GosuNamedOption(id: 9104, name: '기타', colorHex: '#64748b'),
];

const List<GosuNamedOption> kGosuInquiryMethods = [
  GosuNamedOption(id: 1, name: '유선', colorHex: '#2563eb'),
  GosuNamedOption(id: 2, name: '법인폰', colorHex: '#7c3aed'),
  GosuNamedOption(id: 7, name: '톡문의', colorHex: '#ca8a04'),
  GosuNamedOption(id: 9201, name: '블로그카페', colorHex: '#c026d3'),
  GosuNamedOption(id: 9202, name: '지도', colorHex: '#16a34a'),
  GosuNamedOption(id: 9203, name: '재문의', colorHex: '#57534e'),
];

/// 고수 전용 문의종류. 미선택·알 수 없는 값은 단순문의.
const List<GosuNamedOption> kGosuInquiryKinds = [
  GosuNamedOption(id: 9301, name: '단순문의', colorHex: '#0284c7'),
  GosuNamedOption(id: 9302, name: '기타문의', colorHex: '#64748b'),
  GosuNamedOption(id: 9303, name: '타사AS', colorHex: '#d97706'),
  GosuNamedOption(id: 9304, name: '자사AS', colorHex: '#0f766e'),
];

int? gosuInquiryMethodIdForStorage(int id) => id < 9000 ? id : null;

String normalizeGosuInquiryKind(String? value) {
  final name = (value ?? '').trim();
  for (final kind in kGosuInquiryKinds) {
    if (kind.name == name) return name;
  }
  return kGosuInquiryKindDefault;
}

String? gosuInquiryKindColorHex(String? value) {
  final name = normalizeGosuInquiryKind(value);
  for (final kind in kGosuInquiryKinds) {
    if (kind.name == name) return kind.colorHex;
  }
  return kGosuInquiryKinds.first.colorHex;
}

String? gosuInquiryMethodColorHex(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return null;
  for (final method in kGosuInquiryMethods) {
    if (method.name == name) return method.colorHex;
  }
  return null;
}
