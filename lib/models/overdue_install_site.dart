import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';

class OverdueInstallSite {
  const OverdueInstallSite({
    required this.inqNo,
    required this.instalDt,
    required this.siteNm,
    required this.custNm,
    required this.plantCd,
    required this.plantNm,
    required this.itemCd,
    required this.managerNm,
    required this.regUsr,
    required this.installDone,
    this.itemQty,
    this.inqStatus,
    this.orderTotal,
    this.orderNo,
    this.paidSum,
    this.remainPay,
    this.initialPay,
    this.receivedStatus,
    this.hasUnpaidCache = false,
    this.ourUserNames = const [],
  });

  final String inqNo;
  final String instalDt;
  final String siteNm;
  final String custNm;
  final String plantCd;
  final String plantNm;
  final String itemCd;
  final String managerNm;
  final String regUsr;
  final bool installDone;
  final String? itemQty;
  final String? inqStatus;

  /// 부가세 포함 수주금액.
  final int? orderTotal;
  final String? orderNo;
  final int? paidSum;
  final int? remainPay;
  final int? initialPay;
  final String? receivedStatus;
  final bool hasUnpaidCache;
  final Iterable<String> ourUserNames;

  String get assigneeKey => overdueInstallAssigneeKey(
    managerNm: managerNm,
    regUsr: regUsr,
    ourNames: ourUserNames,
  );

  String get displayName {
    final site = siteNm.trim();
    if (site.isNotEmpty) return site;
    final cust = custNm.trim();
    if (cust.isNotEmpty) return cust;
    return inqNo;
  }

  ({int supply, int tax, int total})? get vatSplit =>
      overdueInstallVatSplit(orderTotal);

  OverdueInstallSite copyWith({
    int? orderTotal,
    String? orderNo,
    int? paidSum,
    int? remainPay,
    int? initialPay,
    String? receivedStatus,
    bool? hasUnpaidCache,
    Iterable<String>? ourUserNames,
  }) {
    return OverdueInstallSite(
      inqNo: inqNo,
      instalDt: instalDt,
      siteNm: siteNm,
      custNm: custNm,
      plantCd: plantCd,
      plantNm: plantNm,
      itemCd: itemCd,
      managerNm: managerNm,
      regUsr: regUsr,
      installDone: installDone,
      itemQty: itemQty,
      inqStatus: inqStatus,
      orderTotal: orderTotal ?? this.orderTotal,
      orderNo: orderNo ?? this.orderNo,
      paidSum: paidSum ?? this.paidSum,
      remainPay: remainPay ?? this.remainPay,
      initialPay: initialPay ?? this.initialPay,
      receivedStatus: receivedStatus ?? this.receivedStatus,
      hasUnpaidCache: hasUnpaidCache ?? this.hasUnpaidCache,
      ourUserNames: ourUserNames ?? this.ourUserNames,
    );
  }
}

class OverdueInstallArchivePhoto {
  const OverdueInstallArchivePhoto({
    required this.id,
    required this.kind,
    required this.mediaPath,
    this.originalName,
  });

  final String id;
  final OverdueInstallArchiveKind kind;
  final String mediaPath;
  final String? originalName;
}

class OverdueInstallArchive {
  const OverdueInstallArchive({
    this.installAfter = const [],
    this.contracts = const [],
    this.checksheets = const [],
  });

  final List<OverdueInstallArchivePhoto> installAfter;
  final List<OverdueInstallArchivePhoto> contracts;
  final List<OverdueInstallArchivePhoto> checksheets;

  bool get isEmpty => contracts.isEmpty && checksheets.isEmpty;
}
