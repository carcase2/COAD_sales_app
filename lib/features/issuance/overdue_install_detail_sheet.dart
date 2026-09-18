import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showOverdueInstallDetailSheet({
  required BuildContext context,
  required OverdueInstallSite site,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _OverdueInstallDetailSheet(site: site),
  );
}

class _OverdueInstallDetailSheet extends StatelessWidget {
  const _OverdueInstallDetailSheet({required this.site});

  final OverdueInstallSite site;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vat = site.vatSplit;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              site.displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '시공완료 안 됨',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.deepOrange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _kv('담당자', site.assigneeKey),
            _kv('시공예정일', site.instalDt),
            if (site.custNm.isNotEmpty && site.custNm != site.siteNm)
              _kv('고객', site.custNm),
            _kv('인쿼리', site.inqNo),
            _kv('지점', site.plantNm.isEmpty ? site.plantCd : site.plantNm),
            if (site.itemCd.isNotEmpty) _kv('품목', site.itemCd),
            if ((site.itemQty ?? '').isNotEmpty) _kv('수량', site.itemQty!),
            if ((site.inqStatus ?? '').isNotEmpty) _kv('상태', site.inqStatus!),
            const Divider(height: 28),
            Text(
              '금액',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            if (vat == null)
              Text(
                '수주금액 정보가 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              _kv('공급가액', _won(vat.supply)),
              _kv('세액', _won(vat.tax)),
              _kv('합계 (부가세 포함)', _won(vat.total)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _won(int n) => '${NumberFormat('#,###').format(n)}원';
}
