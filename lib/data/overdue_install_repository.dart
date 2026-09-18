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
          ourUserNames: ourNames,
        ),
      );
    }
    return _fillMissingOrderPrice(sites);
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

  Future<List<OverdueInstallSite>> _fillMissingOrderPrice(
    List<OverdueInstallSite> sites,
  ) async {
    final missing = sites
        .where((s) => s.orderTotal == null && s.inqNo.isNotEmpty)
        .map((s) => s.inqNo)
        .toSet()
        .toList();
    if (missing.isEmpty) return sites;

    final prices = <String, int>{};
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
          final price = overdueInstallOrderPriceFromRaw(row['raw_data']);
          if (inq.isNotEmpty && price != null) prices[inq] = price;
        }
      }
    } catch (_) {
      return sites;
    }
    if (prices.isEmpty) return sites;
    return [
      for (final site in sites)
        prices.containsKey(site.inqNo)
            ? site.copyWith(orderTotal: prices[site.inqNo])
            : site,
    ];
  }
}
