import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OverdueInstallRepository {
  OverdueInstallRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _pageSize = 1000;
  static const _maxRows = 4000;
  static const _inqChunk = 80;

  /// 예정일이 [fromYmd]~[toYmd] 이고 시공완료가 아닌 건.
  Future<List<OverdueInstallSite>> fetchPendingOverdue({
    required String fromYmd,
    required String toYmd,
    required String todayYmd,
  }) async {
    final all = await _pageInquiries(fromYmd: fromYmd, toYmd: toYmd);
    final ourNames = await _fetchOurUserNames();

    final sites = <OverdueInstallSite>[];
    for (final raw in all) {
      final plantCd = (raw['plant_cd'] ?? '').toString();
      if (overdueInstallIsJapanPlant(plantCd)) continue;
      if (overdueInstallParseDone(raw['install_done'])) continue;
      final instalDt = (raw['instal_dt'] ?? '').toString();
      if (!overdueInstallIsOverdue(instalDt, todayYmd)) continue;
      sites.add(
        OverdueInstallSite(
          inqNo: (raw['inq_no'] ?? '').toString().trim(),
          instalDt: instalDt.substring(0, 10),
          siteNm: (raw['site_nm'] ?? '').toString().trim(),
          custNm: (raw['cust_nm'] ?? '').toString().trim(),
          plantCd: plantCd.trim(),
          plantNm: (raw['plant_nm'] ?? '').toString().trim(),
          itemCd: (raw['item_cd'] ?? '').toString().trim(),
          managerNm: (raw['manager_nm'] ?? '').toString().trim(),
          regUsr: (raw['reg_usr'] ?? '').toString().trim(),
          installDone: false,
          itemQty: (raw['item_qty'] ?? '').toString().trim(),
          inqStatus: (raw['inq_status'] ?? '').toString().trim(),
          orderTotal: overdueInstallOrderPriceFromRaw(raw['raw_json']),
          remainPay: overdueInstallMoneyFromRaw(raw['raw_json'], const [
            'remain_pay_cost_num',
            'REMAIN_PAY_COST',
            'remain_pay_cost',
            'NON_PRICE',
          ]),
          initialPay: overdueInstallMoneyFromRaw(raw['raw_json'], const [
            'initial_pay_cost_num',
            'INITIAL_PAY_COST',
            'initial_pay_cost',
          ]),
          paidSum: overdueInstallMoneyFromRaw(raw['raw_json'], const [
            'paid_sum_num',
            'PAID_SUM',
          ]),
          receivedStatus:
              (overdueInstallAsMap(raw['raw_json'])?['RECEIVED_STATUS'] ??
                      overdueInstallAsMap(
                        raw['raw_json'],
                      )?['received_status'] ??
                      '')
                  .toString()
                  .trim(),
          ourUserNames: ourNames,
        ),
      );
    }
    final withUnpaid = await _mergeUnpaid(sites);
    return _fillMissingAmounts(withUnpaid);
  }

  Future<Set<String>> _fetchOurUserNames() async {
    Future<Set<String>> parse(dynamic rows) async {
      return {
        for (final row in List<Map<String, dynamic>>.from(rows as List))
          if ((row['name'] ?? '').toString().trim().isNotEmpty)
            (row['name'] ?? '').toString().trim(),
      };
    }

    try {
      final rows = await _client
          .from('users')
          .select('name')
          .eq('is_active', true);
      return parse(rows);
    } catch (_) {
      try {
        final rows = await _client.from('users').select('name');
        return parse(rows);
      } catch (_) {
        return {};
      }
    }
  }

  Future<List<Map<String, dynamic>>> _pageInquiries({
    required String fromYmd,
    required String toYmd,
  }) async {
    const withRaw =
        'inq_no, instal_dt, site_nm, cust_nm, plant_cd, plant_nm, item_cd, item_qty, manager_nm, reg_usr, install_done, inq_status, raw_json';
    const withoutRaw =
        'inq_no, instal_dt, site_nm, cust_nm, plant_cd, plant_nm, item_cd, item_qty, manager_nm, reg_usr, install_done, inq_status';
    var select = withRaw;
    final all = <Map<String, dynamic>>[];
    var from = 0;
    while (from < _maxRows) {
      final to = from + _pageSize - 1;
      try {
        final rows = await _client
            .from('inquiries')
            .select(select)
            .gte('instal_dt', fromYmd)
            .lte('instal_dt', toYmd)
            .eq('install_done', false)
            .order('instal_dt', ascending: false)
            .range(from, to);
        final page = List<Map<String, dynamic>>.from(rows as List);
        all.addAll(page);
        if (page.length < _pageSize) break;
        from += _pageSize;
      } catch (_) {
        if (select == withRaw && from == 0) {
          select = withoutRaw;
          continue;
        }
        rethrow;
      }
    }
    return all;
  }

  Future<List<OverdueInstallSite>> _mergeUnpaid(
    List<OverdueInstallSite> sites,
  ) async {
    final inqNos = sites
        .map((e) => e.inqNo)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (inqNos.isEmpty) return sites;
    final byInq = <String, Map<String, dynamic>>{};
    try {
      for (var i = 0; i < inqNos.length; i += _inqChunk) {
        final end = i + _inqChunk > inqNos.length
            ? inqNos.length
            : i + _inqChunk;
        final chunk = inqNos.sublist(i, end);
        final rows = await _client
            .from('mes_unpaid_receivables')
            .select('inq_no, order_no, snapshot')
            .inFilter('inq_no', chunk);
        for (final row in List<Map<String, dynamic>>.from(rows as List)) {
          final inq = (row['inq_no'] ?? '').toString().trim();
          if (inq.isNotEmpty) byInq[inq] = row;
        }
      }
    } catch (_) {
      return sites;
    }
    if (byInq.isEmpty) return sites;
    return [
      for (final site in sites)
        if (byInq[site.inqNo] == null)
          site
        else
          _fromUnpaid(site, byInq[site.inqNo]!),
    ];
  }

  OverdueInstallSite _fromUnpaid(
    OverdueInstallSite site,
    Map<String, dynamic> row,
  ) {
    final snap = overdueInstallAsMap(row['snapshot']) ?? const {};
    return site.copyWith(
      orderNo: (row['order_no'] ?? snap['ORDER_NO'] ?? '').toString().trim(),
      orderTotal:
          overdueInstallMoneyFromRaw(snap, const [
            'order_price_num',
            'ORDER_PRICE',
          ]) ??
          site.orderTotal,
      paidSum: overdueInstallMoneyFromRaw(snap, const [
        'paid_sum_num',
        'PAID_SUM',
      ]),
      remainPay: overdueInstallMoneyFromRaw(snap, const [
        'remain_pay_cost_num',
        'REMAIN_PAY_COST',
        'non_price_num',
        'NON_PRICE',
      ]),
      initialPay: overdueInstallMoneyFromRaw(snap, const [
        'initial_pay_cost_num',
        'INITIAL_PAY_COST',
      ]),
      receivedStatus: (snap['RECEIVED_STATUS'] ?? '').toString().trim(),
      hasUnpaidCache: true,
    );
  }

  Future<List<OverdueInstallSite>> _fillMissingAmounts(
    List<OverdueInstallSite> sites,
  ) async {
    final missing = sites
        .where(
          (s) =>
              s.inqNo.isNotEmpty &&
              (s.orderTotal == null || s.remainPay == null),
        )
        .map((s) => s.inqNo)
        .toSet()
        .toList();
    if (missing.isEmpty) return sites;

    final extras = <String, Map<String, int?>>{};
    try {
      for (var i = 0; i < missing.length; i += _inqChunk) {
        final end = i + _inqChunk > missing.length
            ? missing.length
            : i + _inqChunk;
        final chunk = missing.sublist(i, end);
        final rows = await _client
            .from('mes_inquiries')
            .select('inq_no, raw_data')
            .inFilter('inq_no', chunk);
        for (final row in List<Map<String, dynamic>>.from(rows as List)) {
          final inq = (row['inq_no'] ?? '').toString().trim();
          if (inq.isEmpty) continue;
          extras[inq] = {
            'order': overdueInstallOrderPriceFromRaw(row['raw_data']),
            'remain': overdueInstallMoneyFromRaw(row['raw_data'], const [
              'remain_pay_cost',
              'REMAIN_PAY_COST',
            ]),
            'initial': overdueInstallMoneyFromRaw(row['raw_data'], const [
              'initial_pay_cost',
              'INITIAL_PAY_COST',
            ]),
          };
        }
      }
    } catch (_) {
      return sites;
    }
    if (extras.isEmpty) return sites;
    return [
      for (final site in sites)
        extras.containsKey(site.inqNo)
            ? site.copyWith(
                orderTotal: extras[site.inqNo]!['order'] ?? site.orderTotal,
                remainPay: extras[site.inqNo]!['remain'] ?? site.remainPay,
                initialPay: extras[site.inqNo]!['initial'] ?? site.initialPay,
              )
            : site,
    ];
  }

  /// R2 아카이브(계약완료보고서·체크시트)를 현장/인쿼리로 찾는다.
  Future<OverdueInstallArchive> fetchSiteArchive({
    required String siteName,
    String? inqNo,
  }) async {
    final site = siteName.trim();
    final inq = (inqNo ?? '').trim();
    if (site.isEmpty && inq.isEmpty) {
      return const OverdueInstallArchive();
    }

    const cols =
        'id, site_name, type_code, stage, original_name, r2_key, local_path';
    final byId = <String, Map<String, dynamic>>{};

    Future<void> addQuery(Future<dynamic> Function() run) async {
      try {
        final res = await run();
        for (final row in List<Map<String, dynamic>>.from(res as List)) {
          final id = (row['id'] ?? '').toString();
          if (id.isNotEmpty) byId[id] = row;
        }
      } catch (_) {}
    }

    final table = _client.from('archive_attachments');
    if (inq.startsWith('SI')) {
      await addQuery(
        () => table.select(cols).ilike('r2_key', '%$inq%').limit(200),
      );
      await addQuery(
        () => table.select(cols).ilike('local_path', '%$inq%').limit(200),
      );
    }
    if (site.isNotEmpty) {
      await addQuery(
        () => table.select(cols).ilike('site_name', '%$site%').limit(200),
      );
      await addQuery(
        () => table.select(cols).ilike('r2_key', '%$site%').limit(200),
      );
      await addQuery(
        () => table
            .select(cols)
            .eq('type_code', 'TP4')
            .ilike('site_name', '%$site%')
            .limit(80),
      );
      await addQuery(
        () => table
            .select(cols)
            .eq('type_code', 'TP1')
            .ilike('site_name', '%$site%')
            .limit(80),
      );
    }

    final contracts = <OverdueInstallArchivePhoto>[];
    final sheets = <OverdueInstallArchivePhoto>[];
    for (final row in byId.values) {
      final kind = overdueInstallArchiveKind(
        typeCode: (row['type_code'] ?? '').toString(),
        stage: (row['stage'] ?? '').toString(),
        r2Key: '${row['r2_key'] ?? ''}|${row['local_path'] ?? ''}',
        originalName: (row['original_name'] ?? '').toString(),
      );
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      if (kind != OverdueInstallArchiveKind.contract &&
          kind != OverdueInstallArchiveKind.checksheet) {
        continue;
      }
      final photo = OverdueInstallArchivePhoto(
        id: id,
        kind: kind,
        mediaPath: 'edge:archive-media?id=${Uri.encodeQueryComponent(id)}',
        originalName: (row['original_name'] ?? '').toString(),
      );
      if (kind == OverdueInstallArchiveKind.contract) {
        contracts.add(photo);
      } else {
        sheets.add(photo);
      }
    }
    return OverdueInstallArchive(
      contracts: contracts.take(24).toList(),
      checksheets: sheets.take(24).toList(),
    );
  }
}
