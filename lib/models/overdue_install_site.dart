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
      ourUserNames: ourUserNames ?? this.ourUserNames,
    );
  }
}
