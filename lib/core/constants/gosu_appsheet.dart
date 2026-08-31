/// 자동문의고수 AppSheet·웹(`coad_home`)과 동일한 분류·문의방법.
const String kGosuGroupName = '자동문의고수';
const String kGosuProgressOpen = '진행중';
const String kGosuProgressClosed = '종료';
const String kGosuStatusReceived = '접수';

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
  GosuNamedOption(id: 1, name: '유선'),
  GosuNamedOption(id: 2, name: '법인폰'),
  GosuNamedOption(id: 7, name: '톡문의'),
  GosuNamedOption(id: 9201, name: '블로그카페'),
  GosuNamedOption(id: 9202, name: '지도'),
  GosuNamedOption(id: 9203, name: '재문의'),
];

int? gosuInquiryMethodIdForStorage(int id) => id < 9000 ? id : null;
